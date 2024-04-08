# Zig StatsD

A client implementation of StatsD in Zig. 

## Using the library

Copy the [src/statsd_client.zig](src/statsd_client.zig) file into your project and import it

```zig
const StatsDClient = @import("statsd_client.zig").StatsDClient;
var client = try StatsDClient.init(.{.host="127.0.0.1", .port=8125, .prefix="my_app"});
```

## Sending metrics

```zig
// Increment a metric by 1
client.incr("my.counter");

// Decrement a metric by 1
client.decr("my.counter");

// Update a gauge to 42
client.gauge("my.gauge", 42.0);

// Increment a gauge by 2
client.gauge_incr("my.gauge", 2.0);

// Send a timer of 15 ms
client.timer("my.timer", 15.0);
```

## License

Licenesed under the [MIT License](LICENSE).