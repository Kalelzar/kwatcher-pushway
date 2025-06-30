const std = @import("std");
const tk = @import("tokamak");
const zmpl = @import("zmpl");
const metrics = @import("../metrics.zig");
const kwatcher = @import("kwatcher");

const PushService = @import("../service/push.zig");
const template = @import("../template.zig");

pub fn @"POST /v1/push/:exchange/:route"(
    res: *tk.Response,
    data: *zmpl.Data,
    push_service: *PushService,
    exchange: []const u8,
    route: []const u8,
    req: std.json.Value,
) !template.Template {
    return doPush(
        res,
        data,
        push_service,
        exchange,
        route,
        req,
    );
}

pub fn @"POST /v1/heartbeat"(
    res: *tk.Response,
    data: *zmpl.Data,
    push_service: *PushService,
    req: kwatcher.schema.Heartbeat.V1(std.json.Value),
) !template.Template {
    return doPush(
        res,
        data,
        push_service,
        "amq.direct",
        "heartbeat",
        req,
    );
}

const ManagedRequest = struct {
    event: []const u8,
};

pub fn @"POST /v1/heartbeat/managed?"(
    res: *tk.Response,
    data: *zmpl.Data,
    push_service: *PushService,
    params: ManagedRequest,
    req: std.json.Value,
) !template.Template {
    const heartbeat: kwatcher.schema.Heartbeat.V1(std.json.Value) = .{
        .properties = req,
        .event = params.event,
        .timestamp = std.time.microTimestamp(),
        .user = (try kwatcher.schema.UserInfo.init(res.arena, null)).v1(),
        .client = .{ //TODO: Inject a ClientInfo instead.
            .version = "0.1.0",
            .name = "pushway",
        },
    };

    return doPush(
        res,
        data,
        push_service,
        "amq.direct",
        "heartbeat",
        heartbeat,
    );
}

fn doPush(
    res: *tk.Response,
    data: *zmpl.Data,
    push_service: *PushService,
    exchange: []const u8,
    route: []const u8,
    req: anytype,
) !template.Template {
    var instr = metrics.instrumentAllocator(res.arena);
    const alloc = instr.allocator();
    const body = try jsonLeaky(alloc, req);
    defer alloc.free(body);

    const response = try push_service.push(
        exchange,
        route,
        body,
    );

    const root = try data.object();
    switch (response) {
        .result => |_| {
            try root.put("status", "ok");
            res.status = 202;
        },
        .err => |e| {
            try root.put("message", e.message);
            try root.put("code", e.code);
            res.status = @intFromEnum(e.code);
        },
    }
    return template.Template.init("not_found");
}

fn jsonLeaky(allocator: std.mem.Allocator, req: anytype) ![]const u8 {
    return std.json.stringifyAlloc(allocator, req, .{});
}
