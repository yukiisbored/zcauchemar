const std = @import("std");
const builtin = @import("builtin");

const Stack = @import("./stack.zig").Stack;

const Self = @This();

frame: FrameStack,
stack: ValueStack,
routines: std.StringHashMap(Routine),

const debug = @import("./constants.zig").debug;

const FrameStack = Stack(Frame, 64);
const ValueStack = Stack(Value, FrameStack.capacity * 256);

pub const RuntimeError = error{
    InvalidType,
    UnknownRoutine,
    MissingEntrypoint,
    AssertFailed,
} || FrameStack.StackError || ValueStack.StackError;

pub const Value = union(enum) {
    n: i32,
    b: bool,

    pub fn print(self: Value, writer: anytype) !void {
        try switch (self) {
            .n => |n| std.fmt.format(writer, "{}", .{n}),
            .b => |b| if (b) writer.writeAll("TRUE") else writer.writeAll("FALSE"),
        };
    }

    pub fn equals(self: Value, other: Value) !bool {
        return switch (self) {
            .n => |a| switch (other) {
                .n => |b| a == b,
                else => error.InvalidType,
            },
            .b => |a| switch (other) {
                .b => |b| a == b,
                else => error.InvalidType,
            },
        };
    }
};

pub const Instruction = union(enum) {
    psh: Value,
    cal: []const u8,
    jmp: usize,
    jif: usize,
    add,
    sub,
    div,
    mul,
    ret,
    nop,

    pub fn print(self: Instruction, writer: anytype) !void {
        try switch (self) {
            .psh => |v| {
                try writer.writeAll("PUSH ");
                try v.print(writer);
            },
            .cal => |v| std.fmt.format(writer, "CALL \"{s}\"", .{v}),
            .jmp => |v| std.fmt.format(writer, "JUMP {d}", .{v}),
            .jif => |v| std.fmt.format(writer, "JUMP-IF-FALSE {d}", .{v}),
            .add => writer.writeAll("ADD"),
            .sub => writer.writeAll("SUB"),
            .div => writer.writeAll("DIV"),
            .mul => writer.writeAll("MUL"),
            .ret => writer.writeAll("RETURN"),
            .nop => writer.writeAll("NOP"),
        };
    }
};

const Routine = union(enum) {
    user: []const Instruction,
    native: *const fn (self: *Self) anyerror!void,
};

const Frame = struct {
    routine: *const Routine,
    ip: usize,
};

pub fn init(allocator: std.mem.Allocator) !Self {
    var res = Self{
        .frame = FrameStack.init(),
        .stack = ValueStack.init(),
        .routines = std.StringHashMap(Routine).init(allocator),
    };

    try res.injectNativeRoutines();

    return res;
}

pub fn deinit(self: *Self) void {
    self.routines.deinit();
}

pub fn addRoutine(self: *Self, name: []const u8, instructions: []const Instruction) !void {
    try self.routines.put(name, Routine{ .user = instructions });
}

fn nativePrint(self: *Self) !void {
    const stdout = std.io.getStdOut().writer();
    try (try self.stack.pop()).print(stdout);
    try stdout.writeAll("\n");
}

fn nativeDrop(self: *Self) !void {
    try self.stack.drop();
}

fn nativeDup(self: *Self) !void {
    try self.stack.push((try self.stack.peek()).*);
}

fn nativeSwap(self: *Self) !void {
    const top = try self.stack.pop();
    const below = try self.stack.pop();
    try self.stack.push(top);
    try self.stack.push(below);
}

fn nativeRot(self: *Self) !void {
    const a = try self.stack.pop();
    const b = try self.stack.pop();
    const c = try self.stack.pop();
    try self.stack.push(b);
    try self.stack.push(a);
    try self.stack.push(c);
}

fn nativeOver(self: *Self) !void {
    const a = try self.stack.pop();
    const b = try self.stack.pop();
    try self.stack.push(b);
    try self.stack.push(a);
    try self.stack.push(b);
}

fn nativeEquals(self: *Self) !void {
    const a = try self.stack.pop();
    const b = try self.stack.pop();
    try self.stack.push(.{ .b = try a.equals(b) });
}

fn nativeAssert(self: *Self) !void {
    switch (try self.stack.pop()) {
        .b => |b| if (!b) return error.AssertFailed,
        else => return error.InvalidType,
    }
}

fn nativeNot(self: *Self) !void {
    try self.stack.push(switch (try self.stack.pop()) {
        .b => |b| .{ .b = !b },
        else => return error.InvalidType,
    });
}

const BooleanBinaryOp = enum {
    @"or",
    @"and",
};

inline fn nativeBooleanBinaryOp(self: *Self, comptime op: BooleanBinaryOp) !void {
    const a = switch (try self.stack.pop()) {
        .b => |b| b,
        else => return error.InvalidType,
    };
    const t = try self.stack.peek();
    const b = switch (t.*) {
        .b => |b| b,
        else => return error.InvalidType,
    };
    const res = switch (op) {
        .@"or" => a or b,
        .@"and" => a and b,
    };
    t.b = res;
}

const NumberComparisonOp = enum {
    gt,
    ge,
    lt,
    le,
};

inline fn nativeNumberComparisonOp(self: *Self, comptime op: NumberComparisonOp) !void {
    const b = switch (try self.stack.pop()) {
        .n => |n| n,
        else => return error.InvalidType,
    };
    const a = switch (try self.stack.pop()) {
        .n => |n| n,
        else => return error.InvalidType,
    };
    const res = switch (op) {
        .gt => a > b,
        .ge => a >= b,
        .lt => a < b,
        .le => a <= b,
    };
    try self.stack.push(Value{ .b = res });
}

// FIXME: Use function definition expressions once it's implemented.
//        https://github.com/ziglang/zig/issues/1717
fn nativeOr(self: *Self) !void {
    return self.nativeBooleanBinaryOp(.@"or");
}

fn nativeAnd(self: *Self) !void {
    return self.nativeBooleanBinaryOp(.@"and");
}

fn nativeGreaterThan(self: *Self) !void {
    return self.nativeNumberComparisonOp(.gt);
}

fn nativeGreaterEqual(self: *Self) !void {
    return self.nativeNumberComparisonOp(.ge);
}

fn nativeLessThan(self: *Self) !void {
    return self.nativeNumberComparisonOp(.lt);
}

fn nativeLessEqual(self: *Self) !void {
    return self.nativeNumberComparisonOp(.le);
}

const NativeRoutine = struct {
    name: []const u8,
    func: *const fn (self: *Self) anyerror!void,
};

fn injectNativeRoutines(self: *Self) !void {
    const xs = comptime [_]NativeRoutine{
        // General purpose
        .{ .name = "PRINT", .func = nativePrint },
        .{ .name = "ASSERT", .func = nativeAssert },
        .{ .name = "EQUALS", .func = nativeEquals },

        // Stack manipulation
        .{ .name = "DROP", .func = nativeDrop },
        .{ .name = "DUP", .func = nativeDup },
        .{ .name = "SWAP", .func = nativeSwap },
        .{ .name = "ROT", .func = nativeRot },
        .{ .name = "OVER", .func = nativeOver },

        // Boolean operations
        .{ .name = "OR", .func = nativeOr },
        .{ .name = "AND", .func = nativeAnd },
        .{ .name = "NOT", .func = nativeNot },

        // Number comparators
        .{ .name = "GREATER-THAN", .func = nativeGreaterThan },
        .{ .name = "GREATER-EQUAL", .func = nativeGreaterEqual },
        .{ .name = "LESS-THAN", .func = nativeLessThan },
        .{ .name = "LESS-EQUAL", .func = nativeLessEqual },
    };

    inline for (xs) |x| {
        try self.routines.put(x.name, .{ .native = x.func });
    }
}

const BinaryOp = enum {
    add,
    sub,
    div,
    mul,
};

inline fn binary_op(self: *Self, comptime op: BinaryOp) RuntimeError!void {
    const b = switch (try self.stack.pop()) {
        .n => |n| n,
        else => return error.InvalidType,
    };
    const t = try self.stack.peek();
    const a = switch (t.*) {
        .n => |n| n,
        else => return error.InvalidType,
    };
    const res = switch (op) {
        .add => a + b,
        .sub => a - b,
        .div => @divTrunc(a, b),
        .mul => a * b,
    };
    t.n = res;
}

pub fn run(self: *Self) !void {
    const program = self.routines.getPtr("PROGRAM") orelse return error.MissingEntrypoint;
    self.frame.push(Frame{ .routine = program, .ip = 0 }) catch unreachable;

    while (true) {
        if (debug) {
            self.printStacktrace(false);
        }

        var frame = try self.frame.peek();
        var ip = frame.ip;

        frame.ip += 1;

        switch (frame.routine.*) {
            .native => |f| {
                try f(self);
                try self.frame.drop();
            },
            .user => |r| {
                var i = r[ip];
                switch (i) {
                    .psh => |p| try self.stack.push(p),
                    .cal => |s| {
                        const routine = self.routines.getPtr(s) orelse return error.UnknownRoutine;
                        try self.frame.push(Frame{
                            .routine = routine,
                            .ip = 0,
                        });
                    },
                    .jmp => |n| frame.ip = n,
                    .jif => |n| {
                        switch (try self.stack.pop()) {
                            .b => |b| if (!b) {
                                frame.ip = n;
                            },
                            else => return error.InvalidType,
                        }
                    },
                    .add => try self.binary_op(.add),
                    .sub => try self.binary_op(.sub),
                    .div => try self.binary_op(.div),
                    .mul => try self.binary_op(.mul),
                    .ret => {
                        try self.frame.drop();
                        if (self.frame.count == 0) {
                            break;
                        }
                    },
                    .nop => {},
                }
            },
        }
    }
}

pub fn printStacktrace(self: *Self, comptime err: bool) void {
    const stderr = std.io.getStdErr().writer();
    const print = std.debug.print;
    print(" STACK: ", .{});
    for (self.stack.items[0..self.stack.count], 0..) |v, i| {
        print("[", .{});
        v.print(stderr) catch {};
        print("]", .{});

        if (i != self.stack.count - 1) {
            print(" ", .{});
        }
    }
    print("\nFRAMES: ", .{});
    for (self.frame.items[0..self.frame.count], 0..) |v, i| {
        if (i > 0) {
            print("        ", .{});
        }
        switch (v.routine.*) {
            .user => |r| {
                const ip = if (err) v.ip - 1 else v.ip;
                if (i == self.frame.count - 1) {
                    print("-> [{d: >5}] ", .{ip});
                } else {
                    print("-- [{d: >5}] ", .{ip});
                }
                r[ip].print(stderr) catch {};
                print("\n", .{});
            },
            .native => |_| {
                print("-> [{d: >5}] -*- NATIVE ROUTINE -*-\n", .{v.ip});
            },
        }
    }
}

pub fn dumpBytecode(self: *Self) void {
    const stderr = std.io.getStdErr().writer();
    const print = std.debug.print;

    var it = self.routines.iterator();
    while (it.next()) |kv| {
        switch (kv.value_ptr.*) {
            .user => |r| {
                print("--- {s} ---\n", .{kv.key_ptr.*});
                for (0.., r) |i, in| {
                    print("[{d: >5}] ", .{i});
                    in.print(stderr) catch {};
                    print("\n", .{});
                }
            },
            else => {},
        }
    }
}
