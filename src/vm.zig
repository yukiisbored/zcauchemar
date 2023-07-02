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
    ip: [FRAMES_MAX]Frame,
    ip_top: usize,

    stack: [STACK_MAX]Value,
    stack_top: usize,

    routines: *std.StringHashMap(Routine),

    const FRAMES_MAX = 64;
    const STACK_MAX = FRAMES_MAX * 256;

    const BinaryOp = enum {
        add,
        sub,
        div,
        mul,
    };

    pub fn init(routines: *std.StringHashMap(Routine)) VM {
        var res = VM{
            .ip = undefined,
            .ip_top = 0,

            .stack = undefined,
            .stack_top = 0,

            .routines = routines,
        };

        const program = res.routines.getPtr("PROGRAM") orelse unreachable;
        res.pushFrame(Frame{ .routine = program, .ip = 0 });

        return res;
    }

    fn pushFrame(self: *VM, frame: Frame) void {
        self.ip[self.ip_top] = frame;
        self.ip_top += 1;
    }

    fn peekFrame(self: *VM) *Frame {
        return &self.ip[self.ip_top - 1];
    }

    fn pullFrame(self: *VM) void {
        self.ip_top -= 1;
    }

    fn pushStack(self: *VM, value: Value) void {
        self.stack[self.stack_top] = value;
        self.stack_top += 1;
    }

    fn peekStack(self: *VM) *Value {
        return &self.stack[self.stack_top - 1];
    }

    fn pullStack(self: *VM) void {
        self.stack_top -= 1;
    }

    fn binary_op(self: *VM, op: BinaryOp) void {
        const b = switch (self.peekStack().*) {
            .n => |n| n,
        };
        self.pullStack();
        const a = switch (self.peekStack().*) {
            .n => |n| n,
        };
        const res = switch (op) {
            .add => a + b,
            .sub => a - b,
            .div => @divTrunc(a, b),
            .mul => a * b,
        };
        self.peekStack().n = res;
    }

    pub fn run(self: *VM) void {
        while (true) {
            var frame = self.peekFrame();
            var ip = frame.ip;
            frame.ip += 1;

            switch (frame.routine.*) {
                .user => |r| {
                    var i = r[ip];
                    switch (i) {
                        .psh => |p| self.pushStack(p.*),
                        .add => self.binary_op(.add),
                        .sub => self.binary_op(.sub),
                        .div => self.binary_op(.div),
                        .mul => self.binary_op(.mul),
                        .ret => {
                            self.pullFrame();
                            if (self.ip_top == 0) {
                                break;
                            }
                        },
                    }
                },
            }
        }
    }
};
