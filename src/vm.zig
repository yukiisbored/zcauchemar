const std = @import("std");

pub const Value = union(enum) {
    n: i32,
};

pub const Instruction = union(enum) {
    psh: *const Value,
    add,
    sub,
    div,
    mul,
    ret,
};

pub const Routine = union(enum) {
    user: []const Instruction,
};

pub const Frame = struct {
    routine: *const Routine,
    ip: usize,
};

pub const VM = struct {
    ip: *std.ArrayList(*Frame),
    stack: *std.ArrayList(Value),
    routines: *std.StringHashMap(*const Routine),

    const BinaryOp = enum {
        add,
        sub,
        div,
        mul,
    };

    fn binary_op(self: *VM, op: BinaryOp) !void {
        const b = switch (self.stack.pop()) {
            .n => |n| n,
        };
        const a = switch (self.stack.pop()) {
            .n => |n| n,
        };
        const res = Value{ .n = switch (op) {
            .add => a + b,
            .sub => a - b,
            .div => @divTrunc(a, b),
            .mul => a * b,
        } };
        try self.stack.append(res);
    }

    pub fn run(self: *VM) !void {
        while (true) {
            var frame = self.ip.items[0].*;
            self.ip.items[0].ip += 1;

            switch (frame.routine.*) {
                .user => |r| {
                    var i = r[frame.ip];
                    switch (i) {
                        .psh => |p| try self.stack.append(p.*),
                        .add => try self.binary_op(.add),
                        .sub => try self.binary_op(.sub),
                        .div => try self.binary_op(.div),
                        .mul => try self.binary_op(.mul),
                        .ret => {
                            _ = self.ip.pop();
                            if (self.ip.items.len == 0) {
                                break;
                            }
                        },
                    }
                },
            }
        }
    }
};
