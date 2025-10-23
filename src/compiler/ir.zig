const std = @import("std");

pub const Instruction = union(enum) {
    plus,
    minus,
    left,
    right,
    loop_start: ?*Instruction,
    loop_end: ?*Instruction,
    input,
    output,
};

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !std.ArrayList(Instruction) {
    var instructions: std.ArrayList(Instruction) = .empty;
    errdefer instructions.deinit(allocator);

    var iter = Iterator(u8).init(source);

    while (iter.next()) |c| {
        const instr: Instruction = switch (c) {
            '+' => .plus,
            '-' => .minus,
            '<' => .left,
            '>' => .right,
            '[' => Instruction{ .loop_start = null },
            ']' => Instruction{ .loop_end = null },
            ',' => .input,
            '.' => .output,
            else => continue,
        };

        try instructions.append(allocator, instr);
    }

    try backpatch(allocator, instructions.items);

    return instructions;
}

fn backpatch(allocator: std.mem.Allocator, instructions: []Instruction) !void {
    var stack: std.ArrayList(*Instruction) = .empty;
    defer stack.deinit(allocator);

    for (instructions) |*i| {
        switch (i.*) {
            .loop_start => try stack.append(allocator, i),
            .loop_end => {
                const start = stack.pop() orelse return error.MismatchedLoops;
                start.loop_start = i;
                i.loop_end = start;
            },
            else => continue,
        }
    }
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

            self.index += 1;
            return self.items[self.index];
        }
    };
}
test "parse" {
    const allocator = std.testing.allocator;
    const test_str = "++++[>++++<-]>.";
    var result = try parse(allocator, test_str);
    defer result.deinit(allocator);

    std.debug.print("{any}", .{result.items});
}
