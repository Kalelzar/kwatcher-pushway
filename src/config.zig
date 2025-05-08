const kwatcher = @import("kwatcher");

pub const PushwayConfig = struct {
    pushway: struct {
        hostname: []const u8 = "0.0.0.0",
        port: u16 = 4269,
    } = .{},
};

pub const Config = kwatcher.meta.MergeStructs(kwatcher.config.BaseConfig, PushwayConfig);
