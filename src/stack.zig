pub fn Stack(
    comptime T: type,
    comptime size: usize,
) type {
    return struct {
        const Self = @This();

        items: [capacity]T,
        count: usize,

        pub const capacity = size;
        pub const StackError = error{ Overflow, Underflow };

        pub inline fn init() Self {
            return Self{
                .items = undefined,
                .count = 0,
            };
        }

        pub inline fn push(self: *Self, item: T) StackError!void {
            if (self.count == capacity) {
                return error.Overflow;
            }
            self.items[self.count] = item;
            self.count += 1;
        }

        pub inline fn peek(self: *Self) StackError!*T {
            if (self.count == 0) {
                return error.Underflow;
            }
            return &self.items[self.count - 1];
        }

        pub inline fn drop(self: *Self) StackError!void {
            if (self.count == 0) {
                return error.Underflow;
            }
            self.count -= 1;
        }

        pub inline fn pop(self: *Self) StackError!T {
            const res = (try self.peek()).*;
            try self.drop();
            return res;
        }
    };
}
