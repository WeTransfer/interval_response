# Base class for all response types, primarily for ease of documentation
class IntervalResponse::Abstract
  def to_rack_response_triplet(headers: nil, chunk_size: IntervalResponse::RackBodyWrapper::CHUNK_SIZE)
    [status_code, headers.to_h.merge(self.headers), IntervalResponse::RackBodyWrapper.new(self, chunk_size: chunk_size)]
  end

  # @param interval_sequence[IntervalResponse::Sequence] the sequence the response is built for
  def initialize(interval_sequence)
    @interval_sequence = interval_sequence
  end

  # Returns the ETag of the interval sequence
  def etag
    @interval_sequence.etag
  end

  # Yields every segment and the range within that segment to be returned to the client. For multipart
  # responses the envelopes of the parts will be returned as segments as well
  #
  # @yield [Object, Range]
  def each
    # No-op
  end

  # Returns the HTTP status code of the response
  #
  # @return [Integer]
  def status_code
    200
  end

  # Returns the exact number of bytes that the response is. If the response
  # is a range it will be the length of the range. If the response is a multipart
  # byte range response it will be the content length of the ranges plus the content
  # length of all the envelopes.
  #
  # @return [Integer]
  def content_length
    0
  end

  # Returns headers for the HTTP response
  # @return [Hash]
  def headers
    {
      'Accept-Ranges' => 'bytes',
      'Content-Length' => '0',
      'Content-Type' => 'binary/octet-stream',
      'ETag' => etag,
    }
  end
end
