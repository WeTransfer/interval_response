require 'spec_helper'
require 'rack/test'

RSpec.describe 'IntervalResponse used in a Rack application' do
  include Rack::Test::Methods
  let(:segments) { @segments || [] }
  let(:app) do
    ->(env) {
      interval_sequence = IntervalResponse::Sequence.new(*segments)
      response = IntervalResponse.new(interval_sequence, env['HTTP_RANGE'], env['HTTP_IF_RANGE'])
      response.to_rack_response_triplet
    }
  end

  it 'returns a full response via the Rack adapter' do
    @segments = ["Mary", " had", " a little", " lamb"]
    get '/words'
    expect(last_response).to be_ok
    expect(last_response.body).to eq("Mary had a little lamb")
  end

  it 'returns a Range response via the Rack adapter' do
    @segments = ["Mary", " had", " a little", " lamb"]
    get '/words', nil, {'HTTP_RANGE' => 'bytes=1-5'}
    expect(last_response.status).to eq(206)
    expect(last_response.content_length).to eq(5)
    expect(last_response.body).to eq("ary h")
  end

  it 'serves from large-ish files' do
    tiny = "tiny string"
    file_a = Tempfile.new('one')
    file_b = Tempfile.new('two')
    file_a.write(Random.new.bytes(4 * 1024 * 1024))
    file_b.write(Random.new.bytes(7 * 1024 * 1024))
    file_a.flush; file_a.rewind
    file_b.flush; file_b.rewind

    @segments = [tiny, file_a, file_b]
    get '/big', nil, {'HTTP_RANGE' => 'bytes=1-5'}
    expect(last_response.status).to eq(206)
    expect(last_response.content_length).to eq(5)

    get '/big', nil, {'HTTP_RANGE' => 'bytes=2-56898'}
    expect(last_response.status).to eq(206)
    expect(last_response.content_length).to eq(56897)
  end
end
