# 0.1.5

* Change the API of `IntervalResponse.new` to accept the Rack `env` hash directly, without having the caller extract the header values manually.
* Allow intervals to set ETags which contribute to the final ETag
* Make #etag available on return value from IntervalResponse.new so that the ETag check can be performed without having to keep the interval sequence object at hand
* Switch the license to MIT-Hippocratic

# 0.1.4

Initial public release