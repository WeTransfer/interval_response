# 0.1.7

* Move `RackResponseWrapper` into the main namespace
* Add `#satisfied_with_first_interval?` so that certain Range: requests can be served using a redirect
* Add `#multiple_ranges?` so that one can choose not to honor multipart Range requests

# 0.1.6

* Create a base response type (`Abstract`) which has the same interface as the rest of the responses

# 0.1.5

* Change the API of `IntervalResponse.new` to accept the Rack `env` hash directly, without having the caller extract the header values manually.
* Allow intervals to set ETags which contribute to the final ETag
* Make #etag available on return value from IntervalResponse.new so that the ETag check can be performed without having to keep the interval sequence object at hand
* Switch the license to MIT-Hippocratic

# 0.1.4

Initial public release