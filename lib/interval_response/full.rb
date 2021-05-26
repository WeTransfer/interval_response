# Serves out a response that contains the entire resource
class IntervalResponse::Full < IntervalResponse::Abstract
  def initialize(*)
    super
    @http_range_for_entire_resource = 0..(@interval_sequence.size - 1)
  end

  def each
    @interval_sequence.each_in_range(@http_range_for_entire_resource) do |segment, range_in_segment|
      yield(segment, range_in_segment)
    end
  end

  def status_code
    200
  end

  def content_length
    @interval_sequence.size
  end

  def satisfied_with_first_interval?
    @interval_sequence.first_interval_only?(@http_range_for_entire_resource)
  end

  def multiple_ranges?
    false
  end

  def headers
    {
      'Accept-Ranges' => 'bytes',
      'Content-Length' => @interval_sequence.size.to_s,
      'Content-Type' => 'binary/octet-stream',
      'ETag' => etag,
    }
  end
end
