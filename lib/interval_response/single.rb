# Serves out a response that consists of one HTTP Range,
# which is always not the entire resource
class IntervalResponse::Single
  include IntervalResponse::ToRackResponseTriplet

  def initialize(interval_map, http_ranges)
    @interval_map = interval_map
    @http_range = http_ranges.first
  end

  def etag
    @interval_map.etag
  end

  # Serve the part of the interval map
  def each
    @interval_map.each_in_range(@http_range) do |segment, range_in_segment|
      yield(segment, range_in_segment)
    end
  end

  def status_code
    206
  end

  def content_length
    @http_range.end - @http_range.begin + 1
  end

  def headers
    c_range = ('bytes %d-%d/%d' % [@http_range.begin, @http_range.end, @interval_map.size])
    {
      'Accept-Ranges' => 'bytes',
      'Content-Length' => (@http_range.end - @http_range.begin + 1).to_s,
      'Content-Type' => 'binary/octet-stream',
      'Content-Range' => c_range,
      'ETag' => etag,
    }
  end
end
