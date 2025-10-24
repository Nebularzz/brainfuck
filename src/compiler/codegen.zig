const std = @import("std");
const ir = @import("ir.zig");

pub const @"x86_64-linux" = struct {
    pub fn generate(allocator: std.mem.Allocator, instrs: []const ir.Instruction) ![]const u8 {
        var code: std.ArrayList(u8) = .empty;
        defer code.deinit(allocator);

        for (instrs) |*inst| {
            switch (inst.*) {
                .plus => |c| try code.print(allocator, "addq ${d}, (%rdi)\n", .{c}),
                .minus => |c| try code.print(allocator, "subq ${d}, (%rdi)\n", .{c}),
                .left => |c| try code.print(allocator, "leaq -{d}(%rdi), %rdi\n", .{c}),
                .right => |c| try code.print(allocator, "leaq {d}(%rdi), %rdi\n", .{c}),
                .output => |c| {
                    for (0..c) |_| {
                        try code.print(allocator, "callq outp\n", .{});
                    }
                },
                .input => |c| {
                    for (0..c) |_| {
                        try code.print(allocator, "callq inp\n", .{});
                    }
                },
                .loop_start => |end| {
                    const format_string =
                        \\_loop_start_{x}:
                        \\movb (%rdi), %cl
                        \\testb %cl, (%rdi)
                        \\je _loop_end_{x}
                        \\
                    ;
                    try code.print(allocator, format_string, .{ @intFromPtr(inst), @intFromPtr(end) });
                },
                .loop_end => |start| {
                    const format_string =
                        \\_loop_end_{x}:
                        \\movb (%rdi), %cl
                        \\testb %cl, (%rdi)
                        \\jne _loop_start_{x}
                        \\
                    ;
                    try code.print(allocator, format_string, .{ @intFromPtr(inst), @intFromPtr(start) });
                },
            }
        }

        return std.fmt.allocPrint(allocator, @embedFile("asm/x86_64-linux.asm"), .{code.items});
    }
};
