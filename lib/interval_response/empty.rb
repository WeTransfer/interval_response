# Serves out a response that is of size 0
class IntervalResponse::Empty
  include IntervalResponse::ToRackResponseTriplet

  def initialize(interval_map)
    @interval_map = interval_map
  end

  def each
    # No-op
  end

  def status_code
    200
  end

  def content_length
    0
  end

  def headers
    {
      'Accept-Ranges' => 'bytes',
      'Content-Length' => '0',
      'Content-Type' => 'binary/octet-stream',
      'ETag' => @interval_map.etag,
    }
  end
end
