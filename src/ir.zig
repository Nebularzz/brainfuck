const std = @import("std");
const Iterator = @import("Iterator.zig").Iterator;

pub const Instruction = union(enum) {
    plus: u64,
    minus: u64,
    left: u64,
    right: u64,
    loop_start: struct {
        name: []const u8,
        end_index: usize,
    },
    loop_end: struct {
        start_index: usize,
    },
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

pub const Instructions = struct {
    allocator: std.mem.Allocator,
    instructions: std.ArrayList(Instruction),

    pub fn init(allocator: std.mem.Allocator, instructions: std.ArrayList(Instruction)) Instructions {
        return Instructions{
            .allocator = allocator,
            .instructions = instructions,
        };
    }

    pub fn deinit(self: *const Instructions) void {
        for (self.instructions.items) |item| {
            switch (item) {
                .loop_start => |start| self.allocator.free(start.name),
                else => {},
            }
        }

        self.instructions.deinit();
    }

    fn countConsecutive(iter: *Iterator(Instruction), tag: std.meta.Tag(Instruction)) usize {
        var count: usize = 0;

        while (iter.next()) |item| : (count += 1) {
            const item_tag = std.meta.activeTag(item);
            if (item_tag != tag) {
                _ = iter.previous();
                break;
            }
        }

        return count;
    }

    const ZeroOpt = union(enum) {
        yes,
        no: usize,
    };

    fn optimizeZero(iterator: *Iterator(Instruction)) ZeroOpt {
        const next1 = iterator.next();
        const next2 = iterator.next();

        if (next1 == null) {
            return .{ .no = 0 };
        }

        if (next2 == null) {
            return .{ .no = 1 };
        }

        const t1 = std.meta.activeTag(next1.?);
        const t2 = std.meta.activeTag(next2.?);

        if ((t1 == .minus or t1 == .plus) and t2 == .loop_end) {
            return ZeroOpt.yes;
        } else {
            return .{ .no = 2 };
        }
    }

    pub fn optimize(self: *Instructions) !void {
        var optimized_instructions = std.ArrayList(Instruction).init(self.allocator);
        var iterator = Iterator(Instruction).init(self.instructions.items);

        var loop_indices = std.ArrayList(usize).init(self.allocator);
        defer loop_indices.deinit();

        var index: usize = 0;

        while (iterator.next()) |inst| : (index += 1) {
            switch (inst) {
                .loop_start => |start| {
                    const can_optimize_zero = optimizeZero(&iterator);

                    switch (can_optimize_zero) {
                        .no => |back| {
                            try optimized_instructions.append(inst);
                            try loop_indices.append(index);

                            for (0..back) |_| {
                                _ = iterator.previous();
                            }

                            continue;
                        },
                        .yes => {
                            try optimized_instructions.append(.zero);
                            self.allocator.free(start.name);
                            continue;
                        },
                    }
                },
                .loop_end => {
                    const idx = loop_indices.pop() orelse return error.InvalidLoop;
                    optimized_instructions.items[idx].loop_start.end_index = index;
                    try optimized_instructions.append(.{ .loop_end = .{ .start_index = idx } });
                },
                .print, .input => try optimized_instructions.append(inst),
                .plus => try optimized_instructions.append(.{ .plus = countConsecutive(&iterator, .plus) + 1 }),
                .minus => try optimized_instructions.append(.{ .minus = countConsecutive(&iterator, .minus) + 1 }),
                .left => try optimized_instructions.append(.{ .left = countConsecutive(&iterator, .left) + 1 }),
                .right => try optimized_instructions.append(.{ .right = countConsecutive(&iterator, .right) + 1 }),
                .zero => try optimized_instructions.append(.zero),
            }
        }

        self.instructions.deinit();
        self.instructions = optimized_instructions;
    }
};

const ParseError = error{
    MismatchedLoops,
};

pub fn parseBrainFuck(allocator: std.mem.Allocator, source: []const u8) !Instructions {
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
                    .loop_end = .{
                        .start_index = start_index,
                    },
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

    var instrs = Instructions{
        .allocator = allocator,
        .instructions = instructions,
    };

    try instrs.optimize();

    return instrs;
}
