const std = @import("std");
const os = std.os;
const net = std.net;
const Allocator = std.mem.Allocator;

pub const StatsDConfig = struct { host: []const u8 = "127.0.0.1", port: u16 = 8125, allocator: Allocator = std.heap.page_allocator, prefix: ?[]const u8 = null };

pub const StatsDClient = struct {
    stream: net.Stream,
    prefix: ?[]const u8,
    allocator: Allocator,

    const Self = @This();

    pub fn init(config: StatsDConfig) !Self {
        const stream = try Self.create_udp_stream(config.host, config.port);
        errdefer stream.close();

        var ret = Self{ .stream = stream, .prefix = null, .allocator = config.allocator };

        if (config.prefix) |pr| {
            const prefix = try config.allocator.alloc(u8, pr.len);
            std.mem.copy(u8, prefix, pr);
            ret.prefix = prefix;
        }

        return ret;
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.prefix);
        self.stream.close();
    }

    fn create_udp_stream(host: []const u8, port: u16) !net.Stream {
        const addr = try net.Address.resolveIp(host, port);
        const fd = try os.socket(os.AF.INET, os.SOCK.DGRAM | os.SOCK.CLOEXEC, 0);
        errdefer os.closeSocket(fd);
        try os.connect(fd, &addr.any, addr.getOsSockLen());
        return net.Stream{ .handle = fd };
    }

    fn alloc_metric(self: Self, slices: []const[]const u8) ![]u8 {
        if (self.prefix) |prefix| {
            var buf_size: usize = prefix.len + 1;
            for (slices) |slice| {
                buf_size += slice.len;
            }
            const buf = try self.allocator.alloc(u8, buf_size);
            errdefer self.allocator.free(buf);

            std.mem.copy(u8, buf, prefix);
            std.mem.copy(u8, buf, ".");
            var buf_index: usize = prefix.len + 1;
            for (slices) |slice| {
                std.mem.copy(u8, buf[buf_index..], slice);
                buf_index += slice.len;
            }
            return buf;
        } else {
            return std.mem.concat(self.allocator, u8, slices);
        }
    }

    fn number_to_str(self: Self, a: anytype) ![]u8 {
        return std.fmt.allocPrint(self.allocator, "{d}", .{a});
    }

    pub fn count(self: Self, metric_name: []const u8, value: f64) !void {
        const value_str = try self.number_to_str(value);
        defer self.allocator.free(value_str);

        const metric = try self.alloc_metric(&[_][]const u8{metric_name, ":", value_str, "|c" });
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

        const metric = try self.alloc_metric(&[_][]const u8{metric_name, ":", value_str, "|ms" });
        defer self.allocator.free(metric);

        try self.stream.writeAll(metric);
    }

    pub fn gauge(self: Self, metric_name: []const u8, value: f64) !void {
        const value_str = try self.number_to_str(value);
        defer self.allocator.free(value_str);

        const metric = try self.alloc_metric(&[_][]const u8{metric_name, ":", value_str, "|g" });
        defer self.allocator.free(metric);

        try self.stream.writeAll(metric);
    }
};