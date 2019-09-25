require 'spec_helper'
require 'complexity_assert'

RSpec.describe IntervalResponse::Sequence do
  context 'with a number of sized segments' do
    it 'allows interval queries and yields tuples with the given object and the range inside it' do
      seq = described_class.new
      expect(seq.size).to eq(0)
      expect(seq).to be_empty

      a = double(:a, size: 6)
      b = double(:b, size: 12)
      c = double(:c, size: 17)
      seq << a << b << c

      expect(seq).not_to be_empty
      expect(seq.size).to eq(6 + 12 + 17)
      expect { |b|
        seq.each_in_range(0..0, &b)
      }.to yield_with_args(a, 0..0)

      expect { |b|
        seq.each_in_range(0..7, &b)
      }.to yield_successive_args([a, 0..5], [b, 0..1])

      expect { |b|
        seq.each_in_range(7..27, &b)
      }.to yield_successive_args([b, 1..11], [c, 0..9])

      expect { |b|
        seq.each_in_range(0..(6 + 12 - 1), &b)
      }.to yield_successive_args([a, 0..5], [b, 0..11])
    end

    it 'generates the ETag for an empty sequence, and the etag contains data' do
      seq = described_class.new
      etag_for_sequence = seq.etag
      expect(etag_for_sequence).to start_with('"')
      expect(etag_for_sequence).to end_with('"')
      expect(etag_for_sequence.bytesize).to be > 8
    end

    it 'generates the ETag dependent on the sequence composition' do
      a = double(:a, size: 6)
      b = double(:b, size: 12)
      c = double(:c, size: 17)
      seq = described_class.new(a, b, c)
      etag_for_sequence = seq.etag
      expect(etag_for_sequence).to start_with('"')
      expect(etag_for_sequence).to end_with('"')

      seq = described_class.new(a, b, c)
      etag_for_sequence_of_same_sizes = seq.etag
      expect(etag_for_sequence_of_same_sizes).to eq(etag_for_sequence)

      seq = described_class.new(a, b, double(size: 7))
      etag_for_sequence_of_same_sizes = seq.etag
      expect(etag_for_sequence_of_same_sizes).not_to eq(etag_for_sequence)
    end

    it 'can handle a range that stretches outside of the available range' do
      a = double('a', size: 3)
      b = double('b', size: 4)
      c = double('c', size: 1)

      seq = described_class.new(a, b, c)
      expect { |b|
        seq.each_in_range(0..27, &b)
      }.to yield_successive_args([a, 0..2], [b, 0..3], [c, 0..0])
    end

    it 'is composable' do
      a = double('a', size: 3)
      b = double('b', size: 4)
      c = double('c', size: 1)

      seq = described_class.new(a, b, described_class.new(c))

      expect { |b|
        seq.each_in_range(0..27, &b)
      }.to yield_successive_args([a, 0..2], [b, 0..3], [c, 0..0])
    end

    it 'has close to linear performance with large number of ranges and intervals' do
      module RangeIntervalCombinedComplexity
        ONE_SEGMENT = Struct.new(:size).new(13)
        def self.generate_args(size)
          intervals = [ONE_SEGMENT] * size
          seq = IntervalResponse::Sequence.new(*intervals)
          http_ranges = size.times.map do |n|
            range_start = (n * 13) + 4
            range_end = (n * 13) + 12
            range_start..range_end
          end

          [seq, http_ranges]
        end

        def self.run(seq, http_ranges)
          http_ranges.each do |r|
            seq.each_in_range(r) do |double, range|
              # pass
            end
          end
        end
      end
      expect(RangeIntervalCombinedComplexity).to be_linear
    end

    it 'has close to linear performance with a range in the middle' do
      module SearchInMiddle
        ONE_SEGMENT = Struct.new(:size).new(13)
        def self.generate_args(size)
          intervals = [ONE_SEGMENT] * size
          seq = IntervalResponse::Sequence.new(*intervals)
          range_start = ((size / 2) * 13) + 4
          range_end = ((size / 2) * 13) + 128

          [seq, range_start..range_end]
        end

        def self.run(seq, r)
          seq.each_in_range(r) do |double, range|
            # pass
          end
        end
      end
      expect(SearchInMiddle).to be_linear
    end
  end
end
