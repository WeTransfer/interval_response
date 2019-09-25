# Serves out a response that is of size 0
class IntervalResponse::Invalid
  include IntervalResponse::ToRackResponseTriplet

  ERROR_JSON = '{"message": "Ranges cannot be satisfied"}'

  def initialize(segment_map)
    @interval_map = segment_map
  end

  def each
    full_segment_range = (0..(ERROR_JSON.bytesize - 1))
    yield(ERROR_JSON, full_segment_range)
  end

  def status_code
    416
  end

  def content_length
    ERROR_JSON.bytesize
  end

  def headers
    {
      'Accept-Ranges' => 'bytes',
      'Content-Length' => ERROR_JSON.bytesize.to_s,
      'Content-Type' => 'application/json',
      'Content-Range' => "bytes */#{@interval_map.size}",
      'ETag' => @interval_map.etag,
    }
  end
end
