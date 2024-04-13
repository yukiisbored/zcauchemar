const std = @import("std");
const builtin = @import("builtin");

const Stack = @import("./stack.zig").Stack;
const Scanner = @import("./Scanner.zig");
const utils = @import("./utils.zig");
const Self = @This();

name: []const u8,
source: []const u8,

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

pub const UserRoutine = struct {
    instructions: []const Instruction,
    tokens: []const Scanner.Token,
};

const Routine = union(enum) {
    user: UserRoutine,
    native: *const fn (self: *Self) anyerror!void,
};

const Frame = struct {
    routine: *const Routine,
    ip: usize,
};

pub fn init(allocator: std.mem.Allocator, name: []const u8, source: []const u8) !Self {
    var res = Self{
        .name = name,
        .source = source,
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

pub fn addRoutine(self: *Self, name: []const u8, instructions: []const Instruction, tokens: []const Scanner.Token) !void {
    try self.routines.put(
        name,
        Routine{
            .user = .{
                .instructions = instructions,
                .tokens = tokens,
            },
        },
    );
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
        const ip = frame.ip;

        frame.ip += 1;

        switch (frame.routine.*) {
            .native => |f| {
                try f(self);
                try self.frame.drop();
            },
            .user => |r| {
                const i = r.instructions[ip];
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
    if (!err) print("===\n", .{});
    for (self.frame.items[0..self.frame.count]) |v| {
        switch (v.routine.*) {
            .user => |r| {
                const ip = if (err) v.ip - 1 else v.ip;
                const token = r.tokens[ip];
                print(
                    "{s}:{}:{}: in {s}\n",
                    .{
                        self.name,
                        token.line + 1,
                        token.column - token.str.len + 1,
                        r.tokens[r.tokens.len - 1].str,
                    },
                );
                utils.printLine(stderr, self.source, token.line) catch {};
                for (0..token.column - token.str.len) |_| {
                    print(" ", .{});
                }
                for (0..token.str.len) |_| {
                    print("^", .{});
                }
                print("\n", .{});
            },
            .native => {
                if (!err) {
                    print("???:?:?: in native routine\n", .{});
                }
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
                for (0.., r.instructions) |i, in| {
                    print("[{d: >5}] ", .{i});
                    in.print(stderr) catch {};
                    print("\n", .{});
                }
            },
            else => {},
        }
    }
}
