pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize = 0,

        pub fn init(items: []const T) Self {
            return .{
                .items = items,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.index >= self.items.len)
                return null;

            defer self.index += 1;
            return self.items[self.index];
        }

        pub fn previous(self: *Self) ?T {
            if (self.index == 0)
                return null;

            self.index -= 1;
            return self.items[self.index];
        }

        pub fn goBack(self: *Self, n: usize) void {
            for (0..n) |_|
                _ = self.previous();
        }
    };
}
