# Serves out a response that is of size 0
class IntervalResponse::Empty < IntervalResponse::Abstract
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
      'ETag' => etag,
    }
  end
end
