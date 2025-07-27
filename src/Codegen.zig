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

fn emitBoilerplate(self: *Self) !void {
    try self.assembly.appendSlice(
        \\.section .text
        \\.global _start
        \\
        \\print:
        \\    pushq %rdi
        \\    movq $1, %rax
        \\    movq %rdi, %rsi
        \\    movq $1, %rdi
        \\    movq $1, %rdx
        \\    syscall
        \\    popq %rdi
        \\    retq
        \\
        \\input:
        \\    pushq %rdi
        \\    xorq %rax, %rax
        \\    movq %rdi, %rsi
        \\    xorq %rdi, %rdi
        \\    movq $1, %rdx
        \\    syscall
        \\    popq %rdi
        \\    retq
        \\
        \\_start:
        \\    movq $9, %rax
        \\    xorq %rdi, %rdi
        \\    movq $65536, %rsi
        \\    movq $3, %rdx
        \\    movq $34, %r10
        \\    movq $-1, %r8
        \\    xorq %r9, %r9
        \\    syscall
        \\    movq %rax, %rdi
        \\    pushq %rax
        \\    cmp $-1, %rax
        \\    je EXIT_FAILURE
        \\
    );
    self.indents += 1;
}

fn emitExit(self: *Self) !void {
    try self.emitIndent("popq %rdi\n");
    try self.emitIndent("movq $11, %rax\n");
    try self.emitIndent("movq $65536, %rsi\n");
    try self.emitIndent("syscall\n");

    try self.emitIndent("cmp $-1, %rax\n");
    try self.emitIndent("je EXIT_FAILURE\n");

    try self.emitIndent("movq $60, %rax\n");
    try self.emitIndent("movq $0, %rdi\n");
    try self.emitIndent("syscall\n");

    try self.emitIndent("EXIT_FAILURE:\n");
    self.indents += 1;
    try self.emitIndent("movq $60, %rax\n");
    try self.emitIndent("movq $1, %rdi\n");
    try self.emitIndent("syscall\n");
}

fn emit(self: *Self, assembly: []const u8) !void {
    try self.assembly.appendSlice(assembly);
}

fn emitIndent(self: *Self, assembly: []const u8) !void {
    try self.indent();
    try self.emit(assembly);
}

fn indent(self: *Self) !void {
    for (0..self.indents) |_| {
        try self.assembly.appendSlice("    ");
    }
}

const Commands = struct {
    fn emitPlus(self: *Self, n: u64) !void {
        const assembly = try std.fmt.allocPrint(self.allocator, "addb ${d}, (%rdi)\n", .{n});
        defer self.allocator.free(assembly);

        try self.emitIndent(assembly);
    }

    fn emitMinus(self: *Self, n: u64) !void {
        const assembly = try std.fmt.allocPrint(self.allocator, "subb ${d}, (%rdi)\n", .{n});
        defer self.allocator.free(assembly);

        try self.emitIndent(assembly);
    }

    fn emitLeft(self: *Self, n: u64) !void {
        const assembly = try std.fmt.allocPrint(self.allocator, "subq ${d}, %rdi\n", .{n});
        defer self.allocator.free(assembly);

        try self.emitIndent(assembly);
    }

    fn emitRight(self: *Self, n: u64) !void {
        const assembly = try std.fmt.allocPrint(self.allocator, "addq ${d}, %rdi\n", .{n});
        defer self.allocator.free(assembly);

        try self.emitIndent(assembly);
    }

    fn emitLoopStart(self: *Self, start: anytype) !void {
        const name = start.name;
        try self.emitIndent(name);
        try self.emit(":\n");
        self.indents += 1;
        try self.emitIndent("movb (%rdi), %cl\n");
        try self.emitIndent("testb %cl, (%rdi)\n");

        const identifier = name[10..];

        try self.emitIndent("jz LOOP_END");
        try self.emit(identifier);
        try self.emit("\n");
    }

    fn emitLoopEnd(self: *Self, end: anytype) !void {
        const start_name = self.instructions.instructions.items[end.start_index].loop_start.name;
        try self.emitIndent("movb (%rdi), %cl\n");
        try self.emitIndent("testb %cl, (%rdi)\n");
        const identifier = start_name[10..];
        try self.emitIndent("jnz ");
        try self.emit(start_name);
        try self.emit("\n");
        self.indents -= 1;

        try self.emitIndent("LOOP_END");
        try self.emit(identifier);
        try self.emit(":\n");
    }

    fn emitPrint(self: *Self) !void {
        try self.emitIndent("callq print\n");
    }

    fn emitInput(self: *Self) !void {
        try self.emitIndent("callq input\n");
    }

    fn emitZero(self: *Self) !void {
        try self.emitIndent("movb $0, (%rdi)\n");
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
    try self.emitBoilerplate();
    while (try self.emitNext()) |_| {}
    try self.emitExit();
}
