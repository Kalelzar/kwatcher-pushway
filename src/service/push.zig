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
    exchange: []const u8,
    queue: []const u8,
    route: []const u8,
    req: []const u8,
) !ar.ApiResult(struct {}) {
    try self.client.openChannel(exchange, queue, route);
    const channel = try self.client.getChannel(queue);
    try kwatcher.metrics.publishQueue(queue, exchange);

    channel.publish(.{
        .body = req,
        .options = .{
            .exchange = exchange,
            .queue = queue,
            .routing_key = route,
        },
    }) catch {
        try kwatcher.metrics.publishError(queue, exchange);
        return .{ .err = .{ .code = .internal_server_error, .message = "Internal error" } };
    };

    try kwatcher.metrics.publish(queue, exchange);

    return .{
        .result = .{},
    };
}
