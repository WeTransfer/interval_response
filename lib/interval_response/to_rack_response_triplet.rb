module IntervalResponse::ToRackResponseTriplet
  CHUNK_SIZE = 65 * 1024 # Roughly one TCP kernel buffer

  class RackBodyWrapper
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
              segment.seek(offset, IO::SEEK_SET)
              yield segment.read_nonblock(read_n, buf)
            end
          end
        when String
          with_each_chunk(range_in_segment) do |offset, read_n|
            yield segment.slice(offset, read_n)
          end
        when Tempfile, File, IO
          with_each_chunk(range_in_segment) do |offset, read_n|
            segment.seek(offset, IO::SEEK_SET)
            yield segment.read_nonblock(read_n, buf)
          end
        else
          raise TypeError, "RackBodyWrapper only supports IOs or Strings"
        end
      end
    ensure
      buf.clear
    end

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

  def to_rack_response_triplet(headers: nil, chunk_size: CHUNK_SIZE)
    [status_code, headers.to_h.merge(self.headers), RackBodyWrapper.new(self, chunk_size: chunk_size)]
  end
end
