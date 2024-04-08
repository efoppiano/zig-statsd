const std = @import("std");
const Allocator = std.mem.Allocator;
const Stream = std.net.Stream;
const os = std.os;
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;

const StatsDClient = @import("statsd_client.zig").StatsDClient;

const TestClient = struct {
	read_fd: os.fd_t,
	client: StatsDClient,
	buf: [buf_size]u8,

	const buf_size: usize = 512;

	fn init(prefix: ?[]const u8) !TestClient {
		const fds = try os.pipe();

		const stream = Stream { .handle = fds[1] };
		const client = try StatsDClient.init_with_stream(prefix, stream, std.testing.allocator);
		return .{ .read_fd = fds[0], .client = client, .buf = undefined };
	}

	fn assert_received(self: *TestClient, metric: []const u8) !void {
		const amount_read = try os.read(self.read_fd, self.buf[0..]);
		return expectEqualSlices(u8, metric[0..], self.buf[0..amount_read]);
	}

	fn deinit(self: TestClient) void {
		self.client.deinit();
		os.close(self.read_fd);
	}
};

test "StatsDClient.count should work" {
	var test_client = try TestClient.init(null);
	defer test_client.deinit();
	try test_client.client.count("my_counter", 25);
	try test_client.assert_received("my_counter:25|c");
}

test "StatsDClient.incr should work" {
	var test_client = try TestClient.init(null);
	defer test_client.deinit();
	try test_client.client.incr("my_counter");
	try test_client.assert_received("my_counter:1|c");
}

test "StatsDClient.decr should work" {
	var test_client = try TestClient.init(null);
	defer test_client.deinit();
	try test_client.client.decr("my_counter");
	try test_client.assert_received("my_counter:-1|c");
}

test "StatsDClient.timer should work" {
	var test_client = try TestClient.init(null);
	defer test_client.deinit();
	try test_client.client.timer("my_timer", 83.5);
	try test_client.assert_received("my_timer:83.5|ms");
}

test "StatsDClient.gauge should work" {
	var test_client = try TestClient.init(null);
	defer test_client.deinit();
	try test_client.client.gauge("my_gauge", 99.3);
	try test_client.assert_received("my_gauge:99.3|g");
}

test "StatsDClient.gauge_incr should work" {
	var test_client = try TestClient.init(null);
	defer test_client.deinit();
	try test_client.client.gauge_incr("my_gauge", 8.5);
	try test_client.assert_received("my_gauge:+8.5|g");
}

test "StatsDClient.gauge_decr should work" {
	var test_client = try TestClient.init(null);
	defer test_client.deinit();
	try test_client.client.gauge_decr("my_gauge", 5000);
	try test_client.assert_received("my_gauge:-5000|g");
}

test "StatsDClient appends the prefix at the start of the metric, if not null" {
	var test_client = try TestClient.init("my_prefix");
	defer test_client.deinit();
	try test_client.client.count("my_counter", 114);
	try test_client.assert_received("my_prefix.my_counter:114|c");
}