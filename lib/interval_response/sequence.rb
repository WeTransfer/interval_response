require 'digest'

# Represents a linear sequence of non-overlapping,
# joined intervals. For example, an HTTP response which consists of
# multiple edge included segments, or a timeline with clips joined together.
# Every interval contains a *segment* - an arbitrary object which responds to
# `#size` at time of adding to the IntervalSequence.
class IntervalResponse::Sequence
  Interval = Struct.new(:segment, :size, :offset, :position, :etag)
  private_constant :Interval

  # @return [Integer] the sum of sizes of all the segments of the sequence
  attr_reader :size

  # Creates a new Sequence with given segments.
  #
  # @param segments[Array<#size,#bytesize>] Segments which respond to #size or #bytesize
  def initialize(*segments)
    @intervals = []
    @size = 0
    segments.each { |s| self << s }
  end

  # Adds a segment to the sequence. The segment gets added at the end of the sequence.
  #
  # @param segment[#size,#bytesize] Segment which responds to #size or #bytesize
  # @return self
  def <<(segment)
    segment_size_or_bytesize = segment.respond_to?(:bytesize) ? segment.bytesize : segment.size
    add_segment(segment, size: segment_size_or_bytesize)
  end

  # Adds a segment to the sequence with specifying the size and optionally the ETag value
  # of the segment. ETag defaults to the size of the segment. Segment can be any object
  # as the size gets passed as a keyword argument
  #
  # @param segment[Object] Any object can be used as the segment
  # @param size[Integer] The size of the segment
  # @param etag[Object] An object that defines the ETag for the segment. Can be any object that can
  #   be Marshal.dump - ed.
  # @return self
  def add_segment(segment, size:, etag: size)
    if size > 0
      etag_quoted = '"%s"' % etag
      # We save the index of the interval inside the Struct so that we can
      # use `bsearch` later instead of requiring `bsearch_index` to be available
      @intervals << Interval.new(segment, size, @size, @intervals.length, etag_quoted)
      @size += size
    end
    self
  end

  # Yields every segment which is touched by the given Range in resource in sequence,
  # together with a Range object which defines the necessary part of the segment.
  # For example, calling `each_in_range(0..2)` with 2 segments of size 1 and 2
  # will successively yield [segment1, 0..0] then [segment2, 0..1]
  #
  # Interval sequences can be nested - you can place a Sequence inside another Sequence
  # as a segment. In that case when you call `each_in_range` on the outer Sequence and you
  # need to retrieve data from the inner Sequence which is one of the segments, the call will
  # yield the segments from the inner Sequence, "drilling down" as deep as is appropriate.
  #
  # @param from_range_in_resource[Range] an inclusive Range that specifies the range within the segment map
  # @yield segment[Object], range_in_segment[Range]
  def each_in_range(from_range_in_resource)
    # Skip empty ranges
    requested_range_size = (from_range_in_resource.end - from_range_in_resource.begin) + 1
    return if requested_range_size < 1

    # ...and if the range misses our intervals completely
    included_intervals = intervals_within_range(from_range_in_resource)

    # And normal case - walk through included intervals
    included_intervals.each do |interval|
      int_start = interval.offset
      int_end = interval.offset + interval.size - 1
      req_start = from_range_in_resource.begin
      req_end = from_range_in_resource.end
      range_within_interval = (max(int_start, req_start) - int_start)..(min(int_end, req_end) - int_start)

      # Allow Sequences to be composed together
      if interval.segment.respond_to?(:each_in_range)
        interval.segment.each_in_range(range_within_interval) do |sub_segment, sub_range|
          yield(sub_segment, sub_range)
        end
      else
        yield(interval.segment, range_within_interval)
      end
    end
  end

  # Tells whether the size of the entire sequence is 0
  def empty?
    @size == 0
  end

  # For IE resumes to work, a strong ETag must be set in the response, and a strong
  # comparison must be performed on it.
  #
  # ETags have meaning with Range: requests, because when a client requests
  # a range it will send the ETag back in the If-Range header. That header
  # tells the server that "I want to have the ranges as emitted by the
  # response representation that has output this etag". This is done so that
  # there is a guarantee that the same resource being requested has the same
  # resource length (off of which the ranges get computed), and the ranges
  # can be safely combined by the client. In practice this means that the ETag
  # must contain some "version handle" which stays unchanged as long as the code
  # responsible for generating the response does not change. In our case the response
  # can change due to the following things:
  #
  # * The lengths of the segments change
  # * The contents of the segments changes
  # * Code that outputs the ranges themselves changes, and outputs different offsets of differently-sized resources.
  #   A resource _can_ be differently sized since the MIME multiplart-byte-range response can have its boundary
  #   or per-part headers change, which affects the _size_ of the MIME part headers. Even though the boundary is
  #   not a part of the resource itself, the sizes of the part headers *do* contribute to the envelope size - that
  #   should stay the same as long as the ETag holds.
  #
  # It is important that the returned ETag is a strong ETag (not prefixed with 'W/') and must be
  # enclosed in double-quotes.
  #
  # See for more https://blogs.msdn.microsoft.com/ieinternals/2011/06/03/download-resumption-in-internet-explorer/
  #
  # The ETag value gets derived from the ETags of the segments, which will be Marshal.dump'ed together
  # and then added to the hash digest to produce the final ETag value.
  #
  # @return [String] a string delimited with double-quotes
  def etag
    d = Digest::SHA1.new
    d << IntervalResponse::VERSION
    @intervals.each do |interval|
      d << interval.etag
    end
    '"%s"' % d.hexdigest
  end

  private

  def max(a, b)
    a > b ? a : b
  end

  def min(a, b)
    a < b ? a : b
  end

  def interval_under(offset)
    # For our purposes we would be better served by `bsearch_index`, but it is not available
    # on older Ruby versions which we otherwise can splendidly support. Since when we retrieve
    # the interval under offset we are going to need the index anyway, and since calling `Array#index`
    # will incur another linear scan of the array, we save the index of the interval with the interval itself.
    @intervals.bsearch do |interval|
      # bsearch expects a 0 return value for "exact match".
      # -1 tells it "look to my left" and 1 "look to my right",
      # which is the output of the <=> operator. If we only needed
      # to find the exact offset in a sorted list just <=> would be
      # fine, but since we are looking for offsets within intervals
      # we will expand the the "match" case with "falls within interval".
      if offset >= interval.offset && offset < (interval.offset + interval.size)
        0
      else
        offset <=> interval.offset
      end
    end
  end

  def intervals_within_range(http_range)
    first_touched = interval_under(http_range.begin)

    # The range starts to the right of available range
    return [] unless first_touched

    last_touched = interval_under(http_range.end) || @intervals.last
    @intervals[first_touched.position..last_touched.position]
  end
end
