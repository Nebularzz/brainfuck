const std = @import("std");
const Ir = @import("Ir/Ir.zig");
const Codegen = @import("Codegen.zig");

const InternalError = error{
    NoFileProvided,
};

pub fn main() !void {
    const allocator = std.heap.smp_allocator;
    const stdout = std.io.getStdOut().writer();
    _ = stdout;
    const stderr = std.io.getStdErr().writer();

    var args = std.process.args();
    _ = args.skip();

    const filename = args.next() orelse {
        try stderr.print("Error: must provide file.\n", .{});
        return InternalError.NoFileProvided;
    };

    const is_absolute = std.fs.path.isAbsolute(filename);

    const source_file = if (is_absolute) blk: {
        break :blk try std.fs.openFileAbsolute(filename, .{ .mode = .read_only });
    } else blk: {
        break :blk try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    };

    defer source_file.close();

    const content = try source_file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);

    var ir = try Ir.init(allocator, content);
    defer ir.deinit();
    try ir.optimize();

    var codegen = Codegen.init(ir);
    defer codegen.assembly.deinit();
    try codegen.compile();

    const stem = std.fs.path.stem(filename);

    std.fs.cwd().makeDir("bf-out") catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };

    const assembly_filename = try std.fmt.allocPrint(allocator, "bf-out/{s}.s", .{stem});
    defer allocator.free(assembly_filename);

    const object_filename = try std.fmt.allocPrint(allocator, "bf-out/{s}.o", .{stem});
    defer allocator.free(object_filename);

    const executable_filename = try std.fmt.allocPrint(allocator, "bf-out/{s}", .{stem});
    defer allocator.free(executable_filename);

    const assembly_file = try std.fs.cwd().createFile(assembly_filename, .{});
    defer assembly_file.close();

    try assembly_file.writeAll(codegen.assembly.items);

    const as_term = try assemble(allocator, assembly_filename, object_filename);

    switch (as_term) {
        .Exited => |code| if (code != 0) {
            try stderr.print("as failed with exit code: {d}\n", .{code});
            return;
        },
        else => try stderr.print("fatal error when executing as: {any}\n", .{as_term}),
    }

    const ld_term = try link(allocator, object_filename, executable_filename);

    switch (ld_term) {
        .Exited => |code| if (code != 0) {
            try stderr.print("ld failed with exit code: {d}\n", .{code});
            return;
        },
        else => try stderr.print("fatal error when executing ld: {any}\n", .{ld_term}),
    }
}

fn assemble(allocator: std.mem.Allocator, assembly_path: []const u8, object_path: []const u8) !std.process.Child.Term {
    var as_process = std.process.Child.init(&.{ "as", assembly_path, "-o", object_path }, allocator);
    try as_process.spawn();
    return try as_process.wait();
}

fn link(allocator: std.mem.Allocator, object_path: []const u8, executable_path: []const u8) !std.process.Child.Term {
    var ld_process = std.process.Child.init(&.{ "ld", object_path, "-o", executable_path }, allocator);
    try ld_process.spawn();
    return try ld_process.wait();
}
