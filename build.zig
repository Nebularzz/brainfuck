const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "brainfuck",
        .root_module = b.addModule("brainfuck", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/main.zig"),
        }),
    });

    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);

    if (b.args) |args| {
        run.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run.step);

    const check_step = b.step("check", "Check the app for errors");
    check_step.dependOn(&exe.step);
}
