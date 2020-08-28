# Base class for all response types, primarily for ease of documentation
class IntervalResponse::Abstract

  # The Rack body wrapper is intended to return as the third element
  # of the Rack response triplet. It supports the #each method
  # and will call to the IntervalResponse object given to it
  # at instantiation, filling up a pre-allocated String object
  # with the bytes to be served out.
  class RackBodyWrapper
    # Default size of the chunk (String buffer) which is going to be
    # yielded to the caller of the `each` method.
    # Set toroughly one TCP kernel buffer
    CHUNK_SIZE = 65 * 1024

    def initialize(with_interval_response, chunk_size:)
      @chunk_size = chunk_size
      @interval_response = with_interval_response
    end

    def each
      buf = String.new(capacity: @chunk_size)
      @interval_response.each do |segment, range_in_segment|
        case segment
        when IntervalResponse::LazyFile
          segment.with do |file_handle|
            with_each_chunk(range_in_segment) do |offset, read_n|
              file_handle.seek(offset, IO::SEEK_SET)
              yield file_handle.read(read_n, buf)
            end
          end
        when String
          with_each_chunk(range_in_segment) do |offset, read_n|
            yield segment.slice(offset, read_n)
          end
        when IO, Tempfile
          with_each_chunk(range_in_segment) do |offset, read_n|
            segment.seek(offset, IO::SEEK_SET)
            yield segment.read(read_n, buf)
          end
        else
          raise TypeError, "RackBodyWrapper only supports IOs or Strings"
        end
      end
    ensure
      buf.clear
    end

    private

    def with_each_chunk(range_in_segment)
      range_size = range_in_segment.end - range_in_segment.begin + 1
      start_at_offset = range_in_segment.begin
      n_whole_segments, remainder = range_size.divmod(@chunk_size)

      n_whole_segments.times do |n|
        unit_offset = start_at_offset + (n * @chunk_size)
        yield unit_offset, @chunk_size
      end

      if remainder > 0
        unit_offset = start_at_offset + (n_whole_segments * @chunk_size)
        yield unit_offset, remainder
      end
    end
  end

  def to_rack_response_triplet(headers: nil, chunk_size: RackBodyWrapper::CHUNK_SIZE)
    [status_code, headers.to_h.merge(self.headers), RackBodyWrapper.new(self, chunk_size: chunk_size)]
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
