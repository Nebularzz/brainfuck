const std = @import("std");
const ir = @import("compiler/ir.zig");
const codegen = @import("compiler/Codegen.zig");

var stdout_buf: [4096]u8 = undefined;

pub fn main() !void {
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;

    const allocator = std.heap.smp_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        std.process.fatal("no file provided", .{});
    }

    const file_name = args[1];
    const cwd = std.fs.cwd();

    var file = try cwd.openFile(file_name, .{});
    defer file.close();

    var read_buf: [1024]u8 = undefined;
    var file_reader = file.reader(&read_buf);

    var content_writer = std.Io.Writer.Allocating.init(allocator);
    defer content_writer.deinit();

    _ = try (&content_writer.writer).sendFile(&file_reader, .unlimited);

    const data = content_writer.writer.buffered();

    var instrs = try ir.parse(allocator, data);
    defer instrs.deinit(allocator);

    const code = try codegen.@"x86_64-linux".generate(allocator, instrs.items);
    defer allocator.free(code);

    try stdout.print("{s}", .{code});
    try stdout.flush();
}
