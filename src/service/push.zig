const std = @import("std");

const kwatcher = @import("kwatcher");
const ClientPool = @import("../pool.zig");

const PushService = @This();
const ar = @import("../api_result.zig");

pool: ClientPool,
alloc: std.mem.Allocator,
conf: kwatcher.config.BaseConfig,

pub fn init(
    pool: ClientPool,
    alloc: std.mem.Allocator,
    conf: kwatcher.config.BaseConfig,
) PushService {
    return .{
        .pool = pool,
        .alloc = alloc,
        .conf = conf,
    };
}

pub fn push(
    self: *PushService,
    exchange: []const u8,
    queue: []const u8,
    route: []const u8,
    req: []const u8,
) !ar.ApiResult(struct {}) {
    self.publishWithRetries(
        .{
            .body = req,
            .options = .{
                .exchange = exchange,
                .queue = queue,
                .routing_key = route,
            },
        },
        5,
    ) catch {
        try kwatcher.metrics.publishError(queue, exchange);
        return .{ .err = .{ .code = .internal_server_error, .message = "Internal error" } };
    };

    try kwatcher.metrics.publish(queue, exchange);

    return .{
        .result = .{},
    };
}

fn publishWithRetries(self: *PushService, msg: kwatcher.schema.SendMessage, max_retries: i4) !void {
    var retries: u4 = 0;
    var backoff: u64 = 1;
    const client = try self.pool.lease();
    defer self.pool.unlease(client);
    while (true) {
        run(client.client, msg) catch |e| {
            if (e == error.AuthFailure) {
                return e; // We really can't do anything if the credentials are wrong.
            }

            if (retries > max_retries) {
                std.log.err("Failed to reconnect after {} retries. Aborting...", .{retries});
                return error.ReconnectionFailure;
            }
            std.log.err(
                "Got disconnected with: {}. Retrying ({}) after {} seconds.",
                .{ e, retries, backoff },
            );
            std.time.sleep(backoff * std.time.ns_per_s);
            client.client.deinit();
            client.client.connect(self.alloc, self.conf, "pushway") catch {};
            backoff *= 2;
            retries += 1;
            continue;
        };
        break;
    }
}

fn run(client: kwatcher.Client, msg: kwatcher.schema.SendMessage) !void {
    try client.openChannel(msg.options.exchange, msg.options.queue, msg.options.routing_key);
    const channel = try client.getChannel(msg.options.queue);
    try kwatcher.metrics.publishQueue(msg.options.queue, msg.options.exchange);
    try channel.publish(msg);
}
