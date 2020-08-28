# Serves out a response that consists of one HTTP Range,
# which is always not the entire resource
class IntervalResponse::Single < IntervalResponse::Abstract
  # @param http_range[Range]
  def initialize(interval_sequence, http_range)
    @interval_sequence = interval_sequence
    @http_range = http_range
  end

  # Serve the part of the interval map
  def each
    @interval_sequence.each_in_range(@http_range) do |segment, range_in_segment|
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
    c_range = ('bytes %d-%d/%d' % [@http_range.begin, @http_range.end, @interval_sequence.size])
    {
      'Accept-Ranges' => 'bytes',
      'Content-Length' => (@http_range.end - @http_range.begin + 1).to_s,
      'Content-Type' => 'binary/octet-stream',
      'Content-Range' => c_range,
      'ETag' => etag,
    }
  end
end
