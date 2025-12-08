const std = @import("std");

pub const Instruction = union(enum) {
    plus: usize,
    minus: usize,
    left: usize,
    right: usize,
    loop_start: ?*Instruction,
    loop_end: ?*Instruction,
    input: usize,
    output: usize,
    zero,
};

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !std.ArrayList(Instruction) {
    var instructions: std.ArrayList(Instruction) = .empty;
    defer instructions.deinit(allocator);

    var iter = Iterator(u8).init(source);

    while (iter.next()) |c| {
        const instr: Instruction = switch (c) {
            '+' => .{ .plus = 1 },
            '-' => .{ .minus = 1 },
            '<' => .{ .left = 1 },
            '>' => .{ .right = 1 },
            '[' => Instruction{ .loop_start = null },
            ']' => Instruction{ .loop_end = null },
            ',' => .{ .input = 1 },
            '.' => .{ .output = 1 },
            else => continue,
        };

        try instructions.append(allocator, instr);
    }

    var zeroed = try zero(allocator, instructions.items);
    defer zeroed.deinit(allocator);

    var collapsed = try collapse(allocator, zeroed.items);
    errdefer collapsed.deinit(allocator);

    try backpatch(allocator, collapsed.items);

    return collapsed;
}

fn backpatch(allocator: std.mem.Allocator, instructions: []Instruction) !void {
    var stack: std.ArrayList(*Instruction) = .empty;
    defer stack.deinit(allocator);

    for (instructions) |*i| switch (i.*) {
        .loop_start => try stack.append(allocator, i),
        .loop_end => {
            const start = stack.pop() orelse return error.MismatchedLoops;
            start.loop_start = i;
            i.loop_end = start;
        },
        else => continue,
    };

    if (stack.items.len != 0) {
        return error.MismatchedLoops;
    }
}

fn collapse(allocator: std.mem.Allocator, ir: []const Instruction) !std.ArrayList(Instruction) {
    var iter = Iterator(Instruction).init(ir);
    var collapsed: std.ArrayList(Collapsed) = .empty;
    defer collapsed.deinit(allocator);

    while (countConsecutive(&iter)) |c| {
        try collapsed.append(allocator, c);
    }

    var instructions: std.ArrayList(Instruction) = .empty;
    errdefer instructions.deinit(allocator);

    for (collapsed.items) |value| switch (value.tag) {
        .plus => try instructions.append(allocator, .{ .plus = value.count }),
        .minus => try instructions.append(allocator, .{ .minus = value.count }),
        .left => try instructions.append(allocator, .{ .left = value.count }),
        .right => try instructions.append(allocator, .{ .right = value.count }),
        .input => try instructions.append(allocator, .{ .input = value.count }),
        .output => try instructions.append(allocator, .{ .output = value.count }),
        .loop_start => {
            for (0..value.count) |_| {
                try instructions.append(allocator, .{ .loop_start = null });
            }
        },
        .loop_end => {
            for (0..value.count) |_| {
                try instructions.append(allocator, .{ .loop_end = null });
            }
        },
        .zero => try instructions.append(allocator, .zero),
    };

    return instructions;
}

const Collapsed = struct {
    tag: std.meta.Tag(Instruction),
    count: usize,
};

fn countConsecutive(iter: *Iterator(Instruction)) ?Collapsed {
    const first = iter.next() orelse return null;
    var count: usize = 1;
    while (iter.next()) |inst| : (count += 1) {
        if (std.meta.activeTag(inst) != std.meta.activeTag(first)) {
            _ = iter.previous();
            break;
        }
    }

    return .{
        .tag = std.meta.activeTag(first),
        .count = count,
    };
}

pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize = 0,

        pub fn init(items: []const T) Self {
            return .{ .items = items };
        }

        pub fn next(self: *Self) ?T {
            if (self.index >= self.items.len) {
                return null;
            }

            defer self.index += 1;
            return self.items[self.index];
        }

        pub fn previous(self: *Self) ?T {
            if (self.index == 0) {
                return null;
            }

            self.index -= 1;
            return self.items[self.index];
        }
    };
}

fn zero(allocator: std.mem.Allocator, ir: []const Instruction) !std.ArrayList(Instruction) {
    var with_zeros: std.ArrayList(Instruction) = .empty;
    errdefer with_zeros.deinit(allocator);

    const State = enum {
        start,
        zero,
        append,
        end,
    };

    var index: usize = 0;
    state: switch (State.start) {
        .start => {
            if (index >= ir.len)
                continue :state .end;

            switch (ir[index]) {
                .loop_start => continue :state .zero,
                else => continue :state .append,
            }
        },
        .zero => {
            if (index + 2 >= ir.len) {
                continue :state .append;
            }

            const plus_minus = ir[index + 1];
            const close = ir[index + 2];

            if ((plus_minus == .plus or plus_minus == .minus) and close == .loop_end) {
                try with_zeros.append(allocator, .zero);
                index += 3;
            } else {
                try with_zeros.append(allocator, ir[index]);
                index += 1;
            }

            continue :state .start;
        },
        .append => {
            try with_zeros.append(allocator, ir[index]);
            index += 1;
            continue :state .start;
        },
        .end => {},
    }

    return with_zeros;
}
