const std = @import("std");
const builtin = @import("builtin");

const Self = @This();

ip: [FRAMES_MAX]Frame,
ip_top: usize,

stack: [STACK_MAX]Value,
stack_top: usize,

routines: *std.StringHashMap(Routine),

const DEBUG = builtin.mode == std.builtin.Mode.Debug;

const FRAMES_MAX = 64;
const STACK_MAX = FRAMES_MAX * 256;

pub const RuntimeError = error{
    StackFull,
    StackEmpty,
    FrameFull,
    FrameEmpty,
    InvalidType,
    UnknownRoutine,
};

pub const InitError = error{
    MissingEntrypoint,
};

pub const Value = union(enum) {
    n: i32,
    b: bool,

    pub fn print(self: Value, writer: anytype) !void {
        try switch (self) {
            .n => |n| std.fmt.format(writer, "{}", .{n}),
            .b => |b| if (b) writer.writeAll("TRUE") else writer.writeAll("FALSE"),
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
                try writer.writeAll("PSH ");
                try v.print(writer);
            },
            .cal => |v| std.fmt.format(writer, "CAL {s}", .{v}),
            .jmp => |v| std.fmt.format(writer, "JMP {d}", .{v}),
            .jif => |v| std.fmt.format(writer, "JIF {d}", .{v}),
            .add => writer.writeAll("ADD"),
            .sub => writer.writeAll("SUB"),
            .div => writer.writeAll("DIV"),
            .mul => writer.writeAll("MUL"),
            .ret => writer.writeAll("RET"),
            .nop => writer.writeAll("NOP"),
        };
    }
};

pub const Routine = union(enum) {
    user: []const Instruction,
    native: *const fn (self: *Self) anyerror!void,
};

pub const Frame = struct {
    routine: *const Routine,
    ip: usize,
};

pub fn init(routines: *std.StringHashMap(Routine)) !Self {
    var res = Self{
        .ip = undefined,
        .ip_top = 0,

        .stack = undefined,
        .stack_top = 0,

        .routines = routines,
    };

    try res.injectNativeRoutines();
    const program = res.routines.getPtr("PROGRAM") orelse return error.MissingEntrypoint;
    res.pushFrame(Frame{ .routine = program, .ip = 0 }) catch unreachable;

    return res;
}

fn nativePrint(self: *Self) !void {
    const stdout = std.io.getStdOut().writer();
    try (try self.peekStack()).print(stdout);
    try stdout.writeAll("\n");
    try self.pullStack();
}

fn injectNativeRoutines(self: *Self) !void {
    try self.routines.put("PRINT", Routine{ .native = nativePrint });
}

inline fn pushFrame(self: *Self, frame: Frame) RuntimeError!void {
    if (self.ip_top > FRAMES_MAX) {
        return error.FrameFull;
    }
    self.ip[self.ip_top] = frame;
    self.ip_top += 1;
}

inline fn peekFrame(self: *Self) RuntimeError!*Frame {
    if (self.ip_top == 0) {
        return RuntimeError.FrameEmpty;
    }
    return &self.ip[self.ip_top - 1];
}

inline fn pullFrame(self: *Self) RuntimeError!void {
    if (self.ip_top == 0) {
        return RuntimeError.FrameEmpty;
    }
    self.ip_top -= 1;
}

inline fn pushStack(self: *Self, value: Value) RuntimeError!void {
    if (self.stack_top > STACK_MAX) {
        return error.StackFull;
    }
    self.stack[self.stack_top] = value;
    self.stack_top += 1;
}

inline fn peekStack(self: *Self) RuntimeError!*Value {
    if (self.stack_top == 0) {
        return error.StackEmpty;
    }
    return &self.stack[self.stack_top - 1];
}

inline fn pullStack(self: *Self) RuntimeError!void {
    if (self.stack_top == 0) {
        return error.StackEmpty;
    }
    self.stack_top -= 1;
}

const BinaryOp = enum {
    add,
    sub,
    div,
    mul,
};

inline fn binary_op(self: *Self, op: BinaryOp) RuntimeError!void {
    const b = switch ((try self.peekStack()).*) {
        .n => |n| n,
        else => return error.InvalidType,
    };
    try self.pullStack();
    const a = switch ((try self.peekStack()).*) {
        .n => |n| n,
        else => return error.InvalidType,
    };
    const res = switch (op) {
        .add => a + b,
        .sub => a - b,
        .div => @divTrunc(a, b),
        .mul => a * b,
    };
    (try self.peekStack()).n = res;
}

pub fn run(self: *Self) !void {
    while (true) {
        if (DEBUG) {
            self.printStacktrace();
        }

        var frame = try self.peekFrame();

        var ip = frame.ip;

        frame.ip += 1;
        errdefer frame.ip -= 1;

        switch (frame.routine.*) {
            .native => |f| {
                try f(self);
                try self.pullFrame();
            },
            .user => |r| {
                var i = r[ip];
                switch (i) {
                    .psh => |p| try self.pushStack(p),
                    .cal => |s| {
                        const routine = self.routines.getPtr(s) orelse return error.UnknownRoutine;
                        try self.pushFrame(Frame{
                            .routine = routine,
                            .ip = 0,
                        });
                    },
                    .jmp => |n| frame.ip = n,
                    .jif => |n| {
                        switch ((try self.peekStack()).*) {
                            .b => |b| if (!b) {
                                frame.ip = n;
                            },
                            else => return error.InvalidType,
                        }
                        try self.pullStack();
                    },
                    .add => try self.binary_op(.add),
                    .sub => try self.binary_op(.sub),
                    .div => try self.binary_op(.div),
                    .mul => try self.binary_op(.mul),
                    .ret => {
                        try self.pullFrame();
                        if (self.ip_top == 0) {
                            break;
                        }
                    },
                    .nop => {},
                }
            },
        }
    }
}

pub fn printStacktrace(self: *Self) void {
    const stderr = std.io.getStdErr().writer();
    const print = std.debug.print;
    print("STACK: ", .{});
    for (self.stack[0..self.stack_top], 0..) |i, idx| {
        print("[", .{});
        i.print(stderr) catch {};
        print("]", .{});

        if (idx != self.stack_top - 1) {
            print(" ", .{});
        }
    }
    print("\nFRAMES: ", .{});
    for (self.ip[0..self.ip_top], 0..) |i, idx| {
        if (idx > 0) {
            print("        ", .{});
        }
        switch (i.routine.*) {
            .user => |r| {
                print(">>> [{d: >5}] ", .{i.ip});
                r[i.ip].print(stderr) catch {};
                print("\n", .{});
            },
            .native => |_| {
                print(">>> [{d: >5}] -*- NATIVE ROUTINE -*-\n", .{i.ip});
            },
        }
    }
}
