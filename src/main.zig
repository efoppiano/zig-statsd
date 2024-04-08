const std = @import("std");
const os = std.os;
const net = std.net;
const Allocator = std.mem.Allocator;

pub const StatsDConfig = struct { host: []const u8 = "127.0.0.1", port: u16 = 8125, allocator: Allocator = std.heap.page_allocator, prefix: ?[]const u8 = null };

pub const StatsDClient = struct {
    stream: net.Stream,
    prefix: []const u8,
    allocator: Allocator,

    const Self = @This();

    pub fn init(config: StatsDConfig) !Self {
        const stream = try Self.create_udp_stream(config.host, config.port);
        errdefer stream.close();
        var prefix = try config.allocator.alloc(u8, config.prefix.len);
        std.mem.copy(u8, prefix, config.prefix);

        return Self{ .stream = stream, .prefix = prefix, .allocator = config.allocator };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.prefix);
    }

    fn create_udp_stream(host: []const u8, port: u16) !net.Stream {
        const addr = try net.Address.resolveIp(host, port);
        const fd = try os.socket(os.AF.INET, os.SOCK.DGRAM | os.SOCK.CLOEXEC, 0);
        errdefer os.closeSocket(fd);
        try os.connect(fd, &addr.any, addr.getOsSockLen());
        return net.Stream{ .handle = fd };
    }

    fn number_to_str(self: Self, a: anytype) ![]u8 {
        return std.fmt.allocPrint(self.allocator, "{d}", .{a});
    }

    pub fn count(self: Self, metric_name: []const u8, value: f64) !void {
        const value_str = try self.number_to_str(value);
        defer self.allocator.free(value_str);

        const metric = try std.mem.concat(self.allocator, u8, &[_][]const u8{ self.prefix, ".", metric_name, ":", value_str, "|c" });
        defer self.allocator.free(metric);

        try self.stream.writeAll(metric);
    }

    pub fn incr(self: Self, metric_name: []const u8) !void {
        return self.count(metric_name, 1.0);
    }

    pub fn decr(self: Self, metric_name: []const u8) !void {
        return self.count(metric_name, -1.0);
    }

    pub fn timer(self: Self, metric_name: []const u8, value: f64) !void {
        const value_str = try self.number_to_str(value);
        defer self.allocator.free(value_str);

        const metric = try std.mem.concat(self.allocator, u8, &[_][]const u8{ self.prefix, ".", metric_name, ":", value_str, "|ms" });
        defer self.allocator.free(metric);

        try self.stream.writeAll(metric);
    }

    pub fn gauge(self: Self, metric_name: []const u8, value: f64) !void {
        const value_str = try self.number_to_str(value);
        defer self.allocator.free(value_str);

        const metric = try std.mem.concat(self.allocator, u8, &[_][]const u8{ self.prefix, ".", metric_name, ":", value_str, "|g" });
        defer self.allocator.free(metric);

        try self.stream.writeAll(metric);
    }
};
