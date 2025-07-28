const std = @import("std");

const Iterator = @import("../Iterator.zig").Iterator;

const Ir = @import("Ir.zig");
const Instruction = Ir.Instruction;

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

const Optimize = union(enum) {
    yes,
    no: usize,
};

fn optimizeZero(iterator: *Iterator(Instruction)) Optimize {
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
        return Optimize.yes;
    } else {
        return .{ .no = 2 };
    }
}

pub fn optimize(self: *Ir) !void {
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
                    .no => |n| {
                        try optimized_instructions.append(inst);
                        try loop_indices.append(index);

                        iterator.goBack(n);

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
                try optimized_instructions.append(.{ .loop_end = idx });
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
