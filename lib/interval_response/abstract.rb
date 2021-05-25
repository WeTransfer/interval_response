# Base class for all response types, primarily for ease of documentation
class IntervalResponse::Abstract
  def to_rack_response_triplet(headers: nil, chunk_size: IntervalResponse::RackBodyWrapper::CHUNK_SIZE)
    [status_code, headers.to_h.merge(self.headers), IntervalResponse::RackBodyWrapper.new(self, chunk_size: chunk_size)]
  end

  # Tells whether this response is responding with multiple ranges. If you want to simulate S3 for example,
  # it might be relevant to deny a response from being served if it does respond with multiple ranges -
  # IntervalResponse supports these responses just fine, but S3 doesn't.
  def multiple_ranges?
    false
  end

  # Tells whether this entire requested range can be satisfied with the first available segment within the given Sequence.
  # If it is, then you can redirect to the URL of the first segment instead of streaming the response
  # through - which can be cheaper for your application server. Note that you can redirect to the resource of the first
  # interval only, because otherwise your `Range` header will no longer match. Suppose you have a stitched resource
  # consisting of two segments:
  #
  #   [bytes 0..456]
  #   [bytes 457..890]
  #
  # and your client requests `Range: bytes=0-33`. You can redirect the client to the location of the first interval,
  # and the `Range:` header will be retransmitted to that location and will be satisfied. However, imagine you are requesting
  # the `Range: bytes=510-512` - you _could_ redirect just to the second interval, but the `Range` header is not going to be
  # adjusted by the client, and you are not going to receive the correct slice of the resource. That's why you can only
  # redirect to the first interval only.
  def satisfied_with_first_interval?
    false
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
