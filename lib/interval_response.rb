require 'measurometer'
require 'rack'

module IntervalResponse
  class Error < StandardError; end

  require_relative "interval_response/version"
  require_relative "interval_response/to_rack_response_triplet"
  require_relative "interval_response/sequence"
  require_relative "interval_response/empty"
  require_relative "interval_response/single"
  require_relative "interval_response/invalid"
  require_relative "interval_response/multi"
  require_relative "interval_response/full"
  require_relative "interval_response/lazy_file"

  ENTIRE_RESOURCE_RANGE = 'bytes=0-'

  def self.new(interval_map, http_range_header_value_or_nil, http_if_range_header_or_nil)
    # If the 'If-Range' header is provided but does not match, discard the Range header. It means
    # that the client is requesting a certain representation of the resource and wants a range
    # _within_ that representation, but the representation has since changed and the offsets
    # no longer make sense. In that case we are supposed to answer with a 200 and the full
    # monty.
    if http_if_range_header_or_nil && http_if_range_header_or_nil != interval_map.etag
      Measurometer.increment_counter('interval_response.if_range_mismatch', 1)
      return new(interval_map, ENTIRE_RESOURCE_RANGE, nil)
    end

    if http_if_range_header_or_nil
      Measurometer.increment_counter('interval_response.if_range_match', 1)
    elsif http_range_header_value_or_nil
      Measurometer.increment_counter('interval_response.if_range_not_provided', 1)
    end

    prepare_response(interval_map, http_range_header_value_or_nil, http_if_range_header_or_nil).tap do |res|
      response_type_name_for_metric = res.class.to_s.split('::').last.downcase # Some::Module::Empty => empty
      Measurometer.increment_counter('interval_response.resp_%s' % response_type_name_for_metric, 1)
    end
  end

  def self.prepare_response(interval_map, http_range_header_value_or_nil, _http_if_range_header_or_nil)
    # Case 1 - response of 0 bytes (empty resource).
    # We don't even have to parse the Range header for this since
    # the response will be the same, always.
    return Empty.new(interval_map) if interval_map.empty?

    # Parse the HTTP Range: header
    range_request_header = http_range_header_value_or_nil || ENTIRE_RESOURCE_RANGE
    http_ranges = Rack::Utils.get_byte_ranges(range_request_header, interval_map.size)

    # Case 2 - Client did send us a Range header, but Rack discarded
    # it because it is invalid and cannot be satisfied
    return Invalid.new(interval_map) if http_range_header_value_or_nil && http_ranges.empty?

    # Case 3 - entire resource
    return Full.new(interval_map) if http_ranges.length == 1 && http_ranges.first == (0..(interval_map.size - 1))

    # Case 4 - one content range
    return Single.new(interval_map, http_ranges) if http_ranges.length == 1

    # Case 5 - MIME multipart with multiple content ranges
    Multi.new(interval_map, http_ranges)
  end
end
