const std = @import("std");
const Ir = @import("Ir/Ir.zig");
const Iterator = @import("Iterator.zig").Iterator;

const Self = @This();

allocator: std.mem.Allocator,
assembly: std.ArrayList(u8),
instructions: Ir,
instruction_iterator: Iterator(Ir.Instruction),
indents: usize = 0,

pub fn init(ir: Ir) Self {
    return .{
        .allocator = ir.instructions.allocator,
        .assembly = std.ArrayList(u8).init(ir.instructions.allocator),
        .instructions = ir,
        .instruction_iterator = Iterator(Ir.Instruction).init(ir.instructions.items),
    };
}

fn emitInit(self: *Self) !void {
    const init_asm = @embedFile("asm/init.s");
    try self.emit("{s}", .{init_asm});
    self.indents += 1;
}

fn emitExit(self: *Self) !void {
    const exit_asm = @embedFile("asm/exit.s");
    try self.emit("{s}", .{exit_asm});
}

fn emit(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    try self.assembly.writer().print(fmt, args);
}

fn emitIndent(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    const SPACES = 4;

    try self.indent(SPACES);
    try self.emit(fmt, args);
}

fn indent(self: *Self, n_spaces: usize) !void {
    try self.assembly.appendNTimes(' ', self.indents * n_spaces);
}

const Commands = struct {
    fn emitPlus(self: *Self, n: u64) !void {
        try self.emitIndent("addb ${d}, (%rdi)\n", .{n});
    }

    fn emitMinus(self: *Self, n: u64) !void {
        try self.emitIndent("subb ${d}, (%rdi)\n", .{n});
    }

    fn emitLeft(self: *Self, n: u64) !void {
        try self.emitIndent("leaq -{d}(%rdi), %rdi\n", .{n});
    }

    fn emitRight(self: *Self, n: u64) !void {
        try self.emitIndent("leaq {d}(%rdi), %rdi\n", .{n});
    }

    fn emitLoopStart(self: *Self, start: Ir.Instruction.LoopEnd) !void {
        const name = start.name;
        try self.emitIndent("{s}:\n", .{name});

        self.indents += 1;

        try self.emitIndent("movb (%rdi), %cl\n", .{});
        try self.emitIndent("testb %cl, (%rdi)\n", .{});

        const identifier = name[10..];
        try self.emitIndent("jz LOOP_END{s}\n", .{identifier});
    }

    fn emitLoopEnd(self: *Self, end: usize) !void {
        try self.emitIndent("movb (%rdi), %cl\n", .{});
        try self.emitIndent("testb %cl, (%rdi)\n", .{});

        const start_name = self.instructions.instructions.items[end].loop_start.name;
        try self.emitIndent("jnz {s}\n", .{start_name});

        self.indents -= 1;

        const identifier = start_name[10..];
        try self.emitIndent("LOOP_END{s}:\n", .{identifier});
    }

    fn emitPrint(self: *Self) !void {
        try self.emitIndent("callq print\n", .{});
    }

    fn emitInput(self: *Self) !void {
        try self.emitIndent("callq input\n", .{});
    }

    fn emitZero(self: *Self) !void {
        try self.emitIndent("movb $0, (%rdi)\n", .{});
    }
};

fn emitNext(self: *Self) !?void {
    const instruction = self.instruction_iterator.next() orelse return null;

    switch (instruction) {
        .plus => |n| try Commands.emitPlus(self, n),
        .minus => |n| try Commands.emitMinus(self, n),
        .left => |n| try Commands.emitLeft(self, n),
        .right => |n| try Commands.emitRight(self, n),

        .loop_start => |start| try Commands.emitLoopStart(self, start),
        .loop_end => |end| try Commands.emitLoopEnd(self, end),
        .print => try Commands.emitPrint(self),
        .input => try Commands.emitInput(self),
        .zero => try Commands.emitZero(self),
    }
}

pub fn compile(self: *Self) !void {
    try self.emitInit();
    while (try self.emitNext()) |_| {}
    try self.emitExit();
}
