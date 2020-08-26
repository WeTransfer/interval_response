# Serves out a response that contains the entire resource
class IntervalResponse::Full
  include IntervalResponse::ToRackResponseTriplet

  def initialize(interval_map, *)
    @interval_map = interval_map
  end

  def etag
    @interval_map.etag
  end

  def each
    # serve the part of the interval map
    full_range = 0..(@interval_map.size - 1)
    @interval_map.each_in_range(full_range) do |segment, range_in_segment|
      yield(segment, range_in_segment)
    end
  end

  def status_code
    200
  end

  def content_length
    @interval_map.size
  end

  def headers
    {
      'Accept-Ranges' => 'bytes',
      'Content-Length' => @interval_map.size.to_s,
      'Content-Type' => 'binary/octet-stream',
      'ETag' => etag,
    }
  end
end
