const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tk = b.dependency("tokamak", .{ .target = target, .optimize = optimize });
    const tokamak = tk.module("tokamak");
    const hz = tk.builder.dependency("httpz", .{ .target = target, .optimize = optimize });
    const httpz = hz.module("httpz");
    const metrics = hz.builder.dependency("metrics", .{ .target = target, .optimize = optimize }).module("metrics");
    const zmpl = b.dependency("zmpl", .{ .target = target, .optimize = optimize }).module("zmpl");
    const kwatcher = b.dependency("kwatcher", .{ .target = target, .optimize = optimize }).module("kwatcher");
    const klib = b.dependency("klib", .{ .target = target, .optimize = optimize }).module("klib");
    const uuid = b.dependency("uuid", .{ .target = target, .optimize = optimize }).module("uuid");

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.addImport("tokamak", tokamak);
    lib_mod.addImport("metrics", metrics);
    lib_mod.addImport("httpz", httpz);
    lib_mod.addImport("zmpl", zmpl);
    lib_mod.addImport("kwatcher", kwatcher);
    lib_mod.addImport("klib", klib);
    lib_mod.addImport("uuid", uuid);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("kwatcher_pushway_lib", lib_mod);
    exe_mod.addImport("tokamak", tokamak);
    exe_mod.addImport("metrics", metrics);
    exe_mod.addImport("httpz", httpz);
    exe_mod.addImport("zmpl", zmpl);
    exe_mod.addImport("kwatcher", kwatcher);
    exe_mod.addImport("klib", klib);
    exe_mod.addImport("uuid", uuid);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "kwatcher_pushway",
        .root_module = lib_mod,
    });

    lib.addLibraryPath(.{ .cwd_relative = "." });
    lib.linkSystemLibrary("rabbitmq");

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "kwatcher_pushway",
        .root_module = exe_mod,
    });

    exe.addLibraryPath(.{ .cwd_relative = "." });
    exe.linkSystemLibrary("rabbitmq");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
