const std = @import("std");
const kwatcher = @import("kwatcher");

const ClientPool = @This();

const Resource = struct {
    client: *kwatcher.AmqpClient,
    locked: bool,
};

const PooledClient = struct {
    client: kwatcher.Client,
    id: u8,
};

allocator: std.mem.Allocator,
pool: std.ArrayListUnmanaged(Resource),
conf: kwatcher.config.BaseConfig,
max: u8,
semaphore: std.Thread.Semaphore,
mutex: std.Thread.Mutex,

pub fn init(allocator: std.mem.Allocator, conf: kwatcher.config.BaseConfig, max: u8) !ClientPool {
    const pool = try std.ArrayListUnmanaged(Resource).initCapacity(allocator, max);
    return .{
        .pool = pool,
        .conf = conf,
        .max = max,
        .allocator = allocator,
        .semaphore = .{ .permits = max },
        .mutex = .{},
    };
}

pub fn deinit(self: *ClientPool) void {
    for (self.pool.items) |*item| {
        item.client.client().deinit();
    }
    self.pool.deinit(self.allocator);
}

pub fn lease(self: *ClientPool) !PooledClient {
    try self.semaphore.timedWait(std.time.ns_per_s * 5);
    errdefer self.semaphore.post();

    return self.getUnsynchronized();
}

pub fn getUnsynchronized(self: *ClientPool) !PooledClient {
    self.mutex.lock();
    defer self.mutex.unlock();

    for (self.pool.items, 0..self.pool.items.len) |*res, index| {
        if (!res.locked) {
            res.locked = true;
            return .{
                .client = res.client.client(),
                .id = @truncate(index),
            };
        }
    }

    const ptr = try self.allocator.create(kwatcher.AmqpClient);
    errdefer self.allocator.destroy(ptr);
    ptr.* = try kwatcher.AmqpClient.init(self.allocator, self.conf, "pushway");
    const index = self.pool.items.len;
    self.pool.appendAssumeCapacity(.{
        .client = ptr,
        .locked = true,
    });

    return .{
        .client = ptr.client(),
        .id = @truncate(index),
    };
}

pub fn unlease(self: *ClientPool, client: PooledClient) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.pool.items[client.id].locked = false;
    self.semaphore.post();
}
