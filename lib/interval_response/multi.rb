require 'securerandom'

class IntervalResponse::Multi
  include IntervalResponse::ToRackResponseTriplet

  ALPHABET = ('0'..'9').to_a + ('a'..'z').to_a + ('A'..'Z').to_a

  def initialize(interval_map, http_ranges)
    @interval_map = interval_map
    @http_ranges = http_ranges
    # RFC1521 says that a boundary "must be no longer than 70 characters,
    # not counting the two leading hyphens".
    # Modulo-based random is biased but it doesn't matter much for us (we do not need to
    # be extremely secure here)
    @boundary = SecureRandom.bytes(24).unpack("C*").map { |b| ALPHABET[b % ALPHABET.length] }.join
  end

  def each
    # serve the part of the interval map
    @http_ranges.each_with_index do |http_range, range_i|
      part_header = part_header(range_i, http_range)
      entire_header_range = 0..(part_header.bytesize - 1)
      yield(part_header, entire_header_range)
      @interval_map.each_in_range(http_range) do |segment, range_in_segment|
        yield(segment, range_in_segment)
      end
    end
  end

  def status_code
    206
  end

  def content_length
    # The Content-Length of a multipart response includes the length
    # of all the ranges of the resource, but also the lengths of the
    # multipart part headers - which we need to precompute. To do it
    # we need to run through all of our ranges and output some strings,
    # and if a lot of ranges are involved this can get expensive. So
    # memoize the envelope size (it never changes between calls)
    @envelope_size ||= compute_envelope_size
  end

  def headers
    {
      'Accept-Ranges' => 'bytes',
      'Content-Length' => content_length.to_s,
      'Content-Type' => "multipart/byte-ranges; boundary=#{@boundary}",
      'ETag' => @interval_map.etag,
    }
  end

  private

  def compute_envelope_size
    @http_ranges.each_with_index.inject(0) do |size_sum, (http_range, part_index)|
      header_bytes = part_header(part_index, http_range)
      range_size = http_range.end - http_range.begin + 1
      size_sum + header_bytes.bytesize + range_size
    end
  end

  def part_header(part_index, http_r)
    [
      part_index > 0 ? "\r\n" : "", # Parts follwing the first have to be delimited "at the top"
      "--%s\r\n" % @boundary,
      "Content-Type: binary/octet-stream\r\n",
      "Content-Range: bytes %d-%d/%d\r\n" % [http_r.begin, http_r.end, @interval_map.size],
      "\r\n",
    ].join
  end
end
