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

const stdlib_routines = @import("./stdlib.zig").routines;

pub const RuntimeError = error{
    InvalidType,
    UnknownRoutine,
    MissingEntrypoint,
    AssertFailed,
} || FrameStack.StackError || ValueStack.StackError;

pub const Value = union(enum) {
    n: i32,
    b: bool,
    s: []const u8,

    pub fn print(self: Value, writer: anytype) !void {
        try switch (self) {
            .n => |n| std.fmt.format(writer, "{}", .{n}),
            .b => |b| if (b) writer.writeAll("TRUE") else writer.writeAll("FALSE"),
            .s => |s| writer.writeAll(s),
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
            .s => |a| switch (other) {
                .s => |b| std.mem.eql(u8, a, b),
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

pub const NativeRoutine = struct {
    name: []const u8,
    func: *const fn (self: *Self) anyerror!void,
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

    inline for (stdlib_routines) |r| {
        try res.routines.put(r.name, Routine{ .native = r.func });
    }

    return res;
}

pub fn deinit(self: *Self) void {
    self.routines.deinit();
}

pub fn addRoutine(self: *Self, name: []const u8, instructions: []const Instruction) !void {
    try self.routines.put(name, Routine{ .user = instructions });
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
