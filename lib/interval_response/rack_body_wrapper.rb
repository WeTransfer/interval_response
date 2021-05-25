# The Rack body wrapper is intended to be returned as the third element
# of the Rack response triplet. It supports the #each method
# and will call to the IntervalResponse object given to it
# at instantiation, filling up a pre-allocated String object
# with the bytes to be served out. The String object will then be repeatedly
# yielded to the Rack webserver with the response data. Since Ruby strings
# are mutable, the String object will be sized to a certain capacity and reused
# across calls to save allocations.
class IntervalResponse::RackBodyWrapper
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
