# Zig StatsD

A client implementation of StatsD in Zig. 

## Using the library

### Zigmod

Install the library using [zigmod](https://github.com/nektro/zigmod/)

```bash
zigmod aq add 1/efoppiano/zig-statsd-client
```

Then import the library in your project

```zig
const StatsDClient = @import("zig-statsd-client").StatsDClient;
```

### Manual

Alternatively, you can copy the [src/statsd_client.zig](src/statsd_client.zig) file into your project and import it

```zig
const StatsDClient = @import("statsd_client.zig").StatsDClient;
```

Now you can create a new client and start sending metrics

```zig
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

## Compatibility

This library is compatible with **Zig 0.13.0**

## License

Licensed under the [MIT License](LICENSE).
