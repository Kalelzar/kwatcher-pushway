const kwatcher = @import("kwatcher");
const klib = @import("klib");

pub const PushwayConfig = struct {
    pushway: struct {
        hostname: []const u8 = "0.0.0.0",
        port: u16 = 4269,
        api_keys: [][]const u8 = &.{},
    } = .{},
};

pub const Config = klib.meta.MergeStructs(kwatcher.config.BaseConfig, PushwayConfig);
