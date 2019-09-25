# An interval sequence represents a linear sequence of non-overlapping,
# joined intervals. For example, an HTTP response which consists of
# multiple edge included segments, or a timeline with clips joined together.
# Every interval contains a *segment* - an arbitrary object which responds to
# `#size` at time of adding to the IntervalSequence.
class IntervalResponse::Sequence
  MULTIPART_GENRATOR_FINGERPRINT = 'boo'
  Interval = Struct.new(:segment, :size, :offset, :position)

  attr_reader :size

  def initialize(*segments)
    @intervals = []
    @size = 0
    segments.each {|s| self << s }
  end

  def <<(segment)
    return self if segment.size == 0
    segment_size_or_bytesize = segment.respond_to?(:bytesize) ? segment.bytesize : segment.size
    @intervals << Interval.new(segment, segment_size_or_bytesize, @size, @intervals.length)
    @size += segment.size
    self
  end

  def each_in_range(from_range_in_resource)
    # Skip empty ranges
    requested_range_size = (from_range_in_resource.end - from_range_in_resource.begin) + 1
    return if requested_range_size < 1

    # ...and if the range misses our intervals completely
    included_intervals = intervals_within_range(from_range_in_resource)

    # And normal case - walk through included intervals
    included_intervals.each do |interval|
      int_start, int_end = interval.offset, interval.offset + interval.size - 1
      req_start, req_end = from_range_in_resource.begin, from_range_in_resource.end
      range_within_interval = (max(int_start, req_start) - int_start)..(min(int_end, req_end) - int_start)
      yield(interval.segment, range_within_interval)
    end
  end

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
  def etag
    d = Digest::SHA1.new
    d << IntervalResponse::VERSION
    d << Marshal.dump(@intervals.map(&:size))
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
