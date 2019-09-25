# IntervalResponse

is a little piece of machinery which allows your Rack/Rails application to correctly
serve HTTP `Range:` responses. Features:

* Strong ETags depending on response composition
* Correct response codes/headers/offsets
* `multipart/byte-range` responses
* Segments comprising the body do not have to be materialized into buffers or strings prior to serving
* Responds to both `GET` and `HEAD`, to the latter without body
* Is [measurometer](https://github.com/WeTransfer/measurometer)-instrumented

## Usage

Imagine you have a number of long Strings you want to serve concatenated as a single HTTP resource.
Wrap them in an `IntervalResponse` and return it to Rack:

```
verses_app = ->(env) {
  all_verses = ImportantVerse.all.map(&:verse_text)
  interval_sequence = IntervalResponse::Sequence.new(*all_verses)
  response = IntervalResponse.new(interval_sequence, env['HTTP_RANGE'], env['HTTP_IF_RANGE'])
  response.to_rack_response_triplet
}
```

Or imagine you want to serve out a few very large log files, concatenated together

```
  log_paths = Dir.glob('/tmp/logs/kafkadoop.*.log.gz').sort
  # Wrap them with "lazy file" proxies so that the files
  # do not have to stay open during the entire response output
  lazy_files = log_paths.map { |path| IntervalResponse::LazyFile.new(path) }
  interval_sequence = IntervalResponse::Sequence.new(*lazy_files)
  response = IntervalResponse.new(interval_sequence, env['HTTP_RANGE'], env['HTTP_IF_RANGE'])
  response.to_rack_response_triplet(headers: {'X-Server' => 'teapot'})
```

Note that the headers `IntervalResponse` generates are _very_ specific and will override your
headers. The following headers will be overridden (as they must all be correct for the serving
to work):

```
Accept-Ranges
Content-Length
Content-Type
Content-Range
ETag
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'interval_response'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install interval_response

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/julik/interval_response.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
