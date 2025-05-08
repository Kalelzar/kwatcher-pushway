const std = @import("std");

const kwatcher = @import("kwatcher");

const PushService = @This();
const ar = @import("../api_result.zig");

client: kwatcher.Client,

pub fn init(client: kwatcher.Client) PushService {
    return .{ .client = client };
}

pub fn push(
    self: *const PushService,
    allocator: std.mem.Allocator,
    exchange: []const u8,
    queue: []const u8,
    route: []const u8,
    req: kwatcher.schema.Heartbeat.V1(std.json.Value),
) !ar.ApiResult(struct {}) {
    try self.client.openChannel(exchange, queue, route);
    const channel = try self.client.getChannel(queue);

    channel.publish(.{ .body = try std.json.stringifyAlloc(allocator, req, .{}), .options = .{
        .exchange = exchange,
        .queue = queue,
        .routing_key = route,
    } }) catch return .{ .err = .{ .code = .internal_server_error, .message = "Internal error" } };

    return .{
        .result = .{},
    };
}
