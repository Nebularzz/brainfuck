const std = @import("std");
const ir = @import("compiler/ir.zig");
const codegen = @import("compiler/codegen.zig");

var io_bufs: struct {
    in: [4096]u8 = undefined,
    out: [4096]u8 = undefined,
} = .{};

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var stdout_writer = std.fs.File.stdout().writer(&io_bufs.out);
    const stdout = &stdout_writer.interface;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const file = try if (args.len <= 1) blk: {
        break :blk std.fs.File.stdin();
    } else blk: {
        break :blk std.fs.cwd().openFile(args[1], .{});
    };

    defer if (file.handle != std.posix.STDIN_FILENO) {
        file.close();
    };

    var file_reader = file.reader(&io_bufs.in);

    var content_writer_impl = std.Io.Writer.Allocating.init(allocator);
    errdefer content_writer_impl.deinit();
    const content_writer = &content_writer_impl.writer;

    _ = try content_writer.sendFile(&file_reader, .unlimited);

    const content = try content_writer_impl.toOwnedSlice();
    defer allocator.free(content);

    var instrs = try ir.parse(allocator, content);
    defer instrs.deinit(allocator);

    const code = try codegen.@"x86_64-linux".generate(allocator, instrs.items);
    defer allocator.free(code);

    try stdout.print("{s}", .{code});
    try stdout.flush();
}
