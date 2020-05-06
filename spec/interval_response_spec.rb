RSpec.describe IntervalResponse do
  it "has a version number" do
    expect(IntervalResponse::VERSION).not_to be nil
  end

  context 'with an empty resource' do
    let(:seq) { IntervalResponse::Sequence.new }
    it 'always returns the empty response' do
      response = IntervalResponse.new(seq, _http_range_header = nil, _if_range_header = nil)
      expect(response.status_code).to eq(200)
      expect(response.content_length).to eq(0)
      expect(response.headers).to eq(
        "Accept-Ranges" => "bytes",
        "Content-Length" => "0",
        "Content-Type" => "binary/octet-stream",
        'ETag' => seq.etag,
      )
      expect { |b|
        response.each(&b)
      }.not_to yield_control

      response = IntervalResponse.new(seq, 'bytes=0-', _if_range = nil)
      expect(response.status_code).to eq(200)
      expect(response.content_length).to eq(0)
      expect(response.headers).to eq(
        "Accept-Ranges" => "bytes",
        "Content-Length" => "0",
        "Content-Type" => "binary/octet-stream",
        'ETag' => seq.etag,
      )
      expect { |b|
        response.each(&b)
      }.not_to yield_control
    end
  end

  context 'with intervals containing data' do
    let(:segment_a) { 'yes' }
    let(:segment_b) { ' we ' }
    let(:segment_c) { '!' }

    let(:seq) do
      IntervalResponse::Sequence.new(segment_a, segment_b, segment_c)
    end

    it 'returns the full response if the client did not ask for a Range' do
      response = IntervalResponse.new(seq, _http_range_header = nil, _if_range = nil)
      expect(response.status_code).to eq(200)
      expect(response.content_length).to eq(3 + 4 + 1)
      expect(response.headers).to eq(
        "Accept-Ranges" => "bytes",
        "Content-Length" => "8",
        "Content-Type" => "binary/octet-stream",
        'ETag' => seq.etag,
      )
      expect { |b|
        response.each(&b)
      }.to yield_successive_args([segment_a, 0..2], [segment_b, 0..3], [segment_c, 0..0])
    end

    it 'raises an error if the requested range is invalid' do
      response = IntervalResponse.new(seq, "bytes=6-5", _if_range = nil)
      expect(response.status_code).to eq(416)
      expect(response.headers).to eq(
        "Accept-Ranges" => "bytes",
        'Content-Length' => IntervalResponse::Invalid::ERROR_JSON.bytesize.to_s,
        "Content-Type" => "application/json",
        'Content-Range' => "bytes */#{seq.size}",
        'ETag' => seq.etag
      )
    end

    it 'returns a single HTTP range if the client asked for it and it can be satisfied' do
      response = IntervalResponse.new(seq, "bytes=2-4", _if_range = nil)
      expect(response.status_code).to eq(206)
      expect(response.content_length).to eq(3)
      expect(response.headers).to eq(
        "Accept-Ranges" => "bytes",
        "Content-Length" => "3",
        "Content-Range" => "bytes 2-4/8",
        "Content-Type" => "binary/octet-stream",
        'ETag' => seq.etag,
      )
      expect { |b|
        response.each(&b)
      }.to yield_successive_args([segment_a, 2..2], [segment_b, 0..1])
    end

    it 'returns a single HTTP range if the client asked for it and it can be satisfied, ETag matches' do
      response = IntervalResponse.new(seq, "bytes=2-4", _if_range = seq.etag)
      expect(response.status_code).to eq(206)
      expect(response.content_length).to eq(3)
      expect(response.headers).to eq(
        "Accept-Ranges" => "bytes",
        "Content-Length" => "3",
        "Content-Range" => "bytes 2-4/8",
        "Content-Type" => "binary/octet-stream",
        'ETag' => seq.etag,
      )
      expect { |b|
        response.each(&b)
      }.to yield_successive_args([segment_a, 2..2], [segment_b, 0..1])
    end

    it 'responss with the entier resource if the Range is satisfiable but the If-Range specifies a different ETag than the sequence' do
      response = IntervalResponse.new(seq, _http_range_header = "bytes=12901-", _http_if_range = '"different"')
      expect(response.status_code).to eq(200)
      expect(response.content_length).to eq(8)
      expect(response.headers).to eq(
        "Accept-Ranges" => "bytes",
        "Content-Length" => "8",
        "Content-Type" => "binary/octet-stream",
        'ETag' => seq.etag,
      )
    end

    it 'responds with the range that can be satisfied if asked for 2 of which one is unsatisfiable' do
      response = IntervalResponse.new(seq, _http_range_header = "bytes=0-5,12901-", _http_if_range = nil)
      expect(response.status_code).to eq(206)
      expect(response.content_length).to eq(6)
      expect(response.headers).to eq(
        "Accept-Ranges" => "bytes",
        "Content-Length" => "6",
        "Content-Range" => "bytes 0-5/8",
        "Content-Type" => "binary/octet-stream",
        'ETag' => seq.etag,
      )

      expect { |b|
        response.each(&b)
      }.to yield_successive_args([segment_a, 0..2], [segment_b, 0..2])
    end

    it 'responds with MIME multipart of ranges if the client asked for it and it can be satisfied' do
      response = IntervalResponse.new(seq, _http_range_header = "bytes=0-0,2-2", _http_if_range = nil)
      response.instance_variable_set('@boundary', 'tcROXEYMdRNXRRYstW296yM1')

      expect(response.status_code).to eq(206)
      expect(response.content_length).to eq(190)
      expect(response.headers).to eq(
        "Accept-Ranges" => "bytes",
        "Content-Length" => "190",
        "Content-Type" => "multipart/byte-ranges; boundary=tcROXEYMdRNXRRYstW296yM1",
        'ETag' => seq.etag,
      )

      output = StringIO.new
      response.each do |segment, range|
        output.write(segment[range])
      end

      reference = [
        "--tcROXEYMdRNXRRYstW296yM1\r\n",
        "Content-Type: binary/octet-stream\r\n",
        "Content-Range: bytes 0-0/8\r\n",
        "\r\n",
        "y\r\n",
        "--tcROXEYMdRNXRRYstW296yM1\r\n",
        "Content-Type: binary/octet-stream\r\n",
        "Content-Range: bytes 2-2/8\r\n",
        "\r\n",
        "s",
      ].join
      expect(output.string).to eq(reference)
      expect(output.string.bytesize).to eq(190)
    end
  end
end
