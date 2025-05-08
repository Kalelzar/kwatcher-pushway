const std = @import("std");
const tk = @import("tokamak");
const zmpl = @import("zmpl");
const metrics = @import("../metrics.zig");
const kwatcher = @import("kwatcher");

const PushService = @import("../service/push.zig");
const template = @import("../template.zig");

pub fn @"POST /v1/push/:exchange/:queue/:route"(
    res: *tk.Response,
    data: *zmpl.Data,
    push_service: *PushService,
    exchange: []const u8,
    queue: []const u8,
    route: []const u8,
    req: kwatcher.schema.Heartbeat.V1(std.json.Value),
) !template.Template {
    var instr = metrics.instrumentAllocator(res.arena);
    const alloc = instr.allocator();
    const response = try push_service.push(
        alloc,
        exchange,
        queue,
        route,
        req,
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
