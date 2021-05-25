require 'measurometer'
require 'rack'

module IntervalResponse
  class Error < StandardError; end

  require_relative "interval_response/version"
  require_relative "interval_response/rack_body_wrapper"
  require_relative "interval_response/sequence"
  require_relative "interval_response/abstract"
  require_relative "interval_response/empty"
  require_relative "interval_response/single"
  require_relative "interval_response/invalid"
  require_relative "interval_response/multi"
  require_relative "interval_response/full"
  require_relative "interval_response/lazy_file"

  ENTIRE_RESOURCE_RANGE = 'bytes=0-'

  # Creates a new IntervalResponse object. The object returned does not
  # have a specific class, but is one of the following objects, which
  # all support the same interface:
  #
  # * IntervalResponse::Empty for an empty response
  # * IntervalResponse::Single for a single HTTP range
  # * IntervalResponse::Full for the entire resource
  # * IntervalResponse::Multi for multipart ranges response with multiple HTTP ranges
  # * IntervalResponse::Invalid for responses that are 416 (Unsatisfiable range)
  #
  # @param interval_sequence[IntervalResponse::Sequence] the sequence of segments
  # @param rack_env_headers[Hash] the Rack env, or a Hash containing 'HTTP_RANGE' and 'HTTP_IF_RANGE' headers
  # @return [Empty, Single, Full, Multi, Invalid]
  def self.new(interval_sequence, rack_env_headers)
    http_range_header_value = rack_env_headers['HTTP_RANGE']
    http_if_range_header_value = rack_env_headers['HTTP_IF_RANGE']

    # If the 'If-Range' header is provided but does not match, discard the Range header. It means
    # that the client is requesting a certain representation of the resource and wants a range
    # _within_ that representation, but the representation has since changed and the offsets
    # no longer make sense. In that case we are supposed to answer with a 200 and the full
    # monty.
    if http_if_range_header_value && http_if_range_header_value != interval_sequence.etag
      Measurometer.increment_counter('interval_response.if_range_mismatch', 1)
      return new(interval_sequence, 'HTTP_RANGE' => ENTIRE_RESOURCE_RANGE)
    end

    if http_if_range_header_value
      Measurometer.increment_counter('interval_response.if_range_match', 1)
    elsif http_range_header_value
      Measurometer.increment_counter('interval_response.if_range_not_provided', 1)
    end

    prepare_response(interval_sequence, http_range_header_value).tap do |res|
      response_type_name_for_metric = res.class.to_s.split('::').last.downcase # Some::Module::Empty => empty
      Measurometer.increment_counter('interval_response.resp_%s' % response_type_name_for_metric, 1)
    end
  end

  def self.prepare_response(interval_sequence, http_range_header_value)
    # Case 1 - response of 0 bytes (empty resource).
    # We don't even have to parse the Range header for this since
    # the response will be the same, always.
    return Empty.new(interval_sequence) if interval_sequence.empty?

    # Parse the HTTP Range: header
    range_request_header = http_range_header_value || ENTIRE_RESOURCE_RANGE
    http_ranges = Rack::Utils.get_byte_ranges(range_request_header, interval_sequence.size)

    # Case 2 - Client did send us a Range header, but Rack discarded
    # it because it is invalid and cannot be satisfied
    return Invalid.new(interval_sequence) if http_range_header_value && (http_ranges.nil? || http_ranges.empty?)

    # Case 3 - entire resource
    return Full.new(interval_sequence) if http_ranges.length == 1 && http_ranges.first == (0..(interval_sequence.size - 1))

    # Case 4 - one content range
    return Single.new(interval_sequence, http_ranges[0]) if http_ranges.length == 1

    # Case 5 - MIME multipart with multiple content ranges
    Multi.new(interval_sequence, http_ranges)
  end

  private_class_method :prepare_response
end
