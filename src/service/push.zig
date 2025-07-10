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
    route: []const u8,
    req: []const u8,
) !ar.ApiResult(struct {}) {
    self.publishWithRetries(
        .{
            .body = req,
            .options = .{
                .exchange = exchange,
                .routing_key = route,
                .norecord = true,
            },
        },
        5,
    ) catch {
        try kwatcher.metrics.publishError(route, exchange);
        return .{ .err = .{ .code = .internal_server_error, .message = "Internal error" } };
    };

    try kwatcher.metrics.publish(route, exchange);

    return .{
        .result = .{},
    };
}

fn publishWithRetries(self: *PushService, msg: kwatcher.schema.SendMessage, max_retries: i4) !void {
    var retries: u4 = 0;
    var backoff: u64 = 5;
    const client = try self.pool.lease();
    defer self.pool.unlease(client);
    main_loop: while (true) {
        run(client.client, msg) catch |e| {
            if (e == error.AuthFailure) {
                return e; // We really can't do anything if the credentials are wrong.
            }

            var last_error: anyerror = e;

            while (retries <= max_retries) {
                std.log.err(
                    "Got disconnected with: {}. Retrying ({}) after {} seconds.",
                    .{ last_error, retries, backoff },
                );
                std.time.sleep(backoff * std.time.ns_per_s);
                backoff *= 2;
                retries += 1;
                client.client.disconnect() catch {};
                client.client.connect() catch |ce| {
                    last_error = ce;
                    continue;
                };
                backoff = 5;
                retries = 0;
                continue :main_loop;
            }

            std.log.err("Failed to reconnect after {} retries. Aborting...", .{retries});
            return error.ReconnectionFailure;
        };
        break;
    }
}

fn run(client: kwatcher.Client, msg: kwatcher.schema.SendMessage) !void {
    try kwatcher.metrics.publishQueue(msg.options.routing_key, msg.options.exchange);
    try client.publish(msg, .{});
}
