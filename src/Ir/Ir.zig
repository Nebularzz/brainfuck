const std = @import("std");
const Iterator = @import("../Iterator.zig").Iterator;
const opt = @import("optimize.zig");

const Ir = @This();

pub const ParseError = error{
    MismatchedLoops,
};

pub const Instruction = union(enum) {
    pub const LoopEnd = struct {
        name: []const u8,
        end_index: usize,
    };

    plus: u64,
    minus: u64,
    left: u64,
    right: u64,
    loop_start: LoopEnd,
    loop_end: usize,
    print,
    input,
    zero,

    pub fn deinit(self: *const Instruction, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .loop_start => |start| allocator.free(start.name),
            else => {},
        }
    }
};

allocator: std.mem.Allocator,
instructions: std.ArrayList(Instruction),

pub fn init(allocator: std.mem.Allocator, source: []const u8) !Ir {
    var instructions = std.ArrayList(Instruction).init(allocator);

    errdefer {
        for (instructions.items) |item| {
            item.deinit(allocator);
        }

        instructions.deinit();
    }

    var loop_indices = std.ArrayList(usize).init(allocator);
    defer loop_indices.deinit();

    var char_iterator = Iterator(u8).init(source);
    var loop_depth: usize = 0;
    var loop: usize = 0;
    var index: usize = 0;

    while (char_iterator.next()) |inst| : (index +%= 1) {
        switch (inst) {
            '+' => try instructions.append(.{ .plus = 1 }),
            '-' => try instructions.append(.{ .minus = 1 }),
            '>' => try instructions.append(.{ .right = 1 }),
            '<' => try instructions.append(.{ .left = 1 }),
            '[' => {
                try instructions.append(.{
                    .loop_start = .{
                        .name = try std.fmt.allocPrint(allocator, "LOOP_START_L{d}_D{d}", .{ loop, loop_depth }),
                        .end_index = undefined,
                    },
                });
                loop_depth += 1;
                try loop_indices.append(index);
            },
            ']' => {
                const start_index = loop_indices.pop() orelse return ParseError.MismatchedLoops;
                loop_depth -= 1;

                try instructions.append(.{
                    .loop_end = start_index,
                });

                instructions.items[start_index].loop_start.end_index = instructions.items.len - 1;

                loop += 1;
            },
            '.' => try instructions.append(.print),
            ',' => try instructions.append(.input),
            else => {
                index -%= 1;
            },
        }
    }

    if (loop_depth != 0) {
        return ParseError.MismatchedLoops;
    }

    return Ir{
        .allocator = allocator,
        .instructions = instructions,
    };
}

pub fn deinit(self: *const Ir) void {
    for (self.instructions.items) |item| {
        switch (item) {
            .loop_start => |start| self.allocator.free(start.name),
            else => {},
        }
    }

    self.instructions.deinit();
}

pub fn optimize(self: *Ir) !void {
    try opt.optimize(self);
}
