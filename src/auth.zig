const std = @import("std");
const tk = @import("tokamak");
const config = @import("config.zig");

pub fn auth(children: []const tk.Route) tk.Route {
    const H = struct {
        fn handleAuth(ctx: *tk.Context) anyerror!void {
            const apikey = ctx.req.header("x-api-key");

            if (apikey) |key| {
                const conf = try ctx.injector.get(config.Config);
                for (conf.pushway.api_keys) |allowed| {
                    if (std.mem.eql(u8, key, allowed)) {
                        try ctx.next();
                        return;
                    }
                }
            }

            ctx.res.status = 401;
            try ctx.send(void{});
        }
    };

    return .{
        .handler = H.handleAuth,
        .children = children,
    };
}
