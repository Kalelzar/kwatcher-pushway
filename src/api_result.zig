const std = @import("std");
const klib = @import("klib");

pub const ApiResultType = enum {
    result,
    err,
};

pub fn ApiResult(comptime OfType: type) type {
    return union(ApiResultType) {
        result: OfType,
        err: struct {
            message: []const u8,
            code: std.http.Status,
        },
    };
}

pub fn handle(comptime OfType: type, value: anyerror!OfType) !ApiResult(OfType) {
    const res = value catch |e| switch (e) {
        error.Conflict => return .{
            .err = .{
                .code = .conflict,
                .message = "Entity already exists",
            },
        },
        else => |le| return le,
    };

    if (comptime OfType == void) {
        return error.InvalidOperation;
    } else {
        return .{ .result = res };
    }
}

pub fn handleAny(value: anytype) !ApiResult(resolveType(@TypeOf(value))) {
    const T = resolveType(@TypeOf(value));
    return handle(T, value);
}

fn resolveType(value: type) type {
    const info: std.builtin.Type = @typeInfo(value);
    switch (info) {
        .error_set => {
            return void;
        },
        .error_union => |u| {
            return u.payload;
        },
        else => {
            return value;
        },
    }
}
