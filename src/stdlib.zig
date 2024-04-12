const std = @import("std");

const Vm = @import("./Vm.zig");

pub const routines = [_]Vm.NativeRoutine{
    // General purpose
    .{ .name = "PRINT", .func = nativePrint },
    .{ .name = "ASSERT", .func = nativeAssert },
    .{ .name = "EQUALS", .func = nativeEquals },
    .{ .name = "TO", .func = nativeTo },

    // Stack manipulation
    .{ .name = "DROP", .func = nativeDrop },
    .{ .name = "DUP", .func = nativeDup },
    .{ .name = "SWAP", .func = nativeSwap },
    .{ .name = "ROT", .func = nativeRot },
    .{ .name = "OVER", .func = nativeOver },
    .{ .name = "COUNT", .func = nativeCount },
    .{ .name = "IS-EMPTY", .func = nativeIsEmpty },

    // Boolean operations
    .{ .name = "OR", .func = nativeOr },
    .{ .name = "AND", .func = nativeAnd },
    .{ .name = "NOT", .func = nativeNot },

    // Number comparators
    .{ .name = "GREATER-THAN", .func = nativeGreaterThan },
    .{ .name = "GREATER-EQUAL", .func = nativeGreaterEqual },
    .{ .name = "LESS-THAN", .func = nativeLessThan },
    .{ .name = "LESS-EQUAL", .func = nativeLessEqual },

    // Type checks
    .{ .name = "IS-BOOLEAN", .func = nativeIsBoolean },
    .{ .name = "IS-NUMBER", .func = nativeIsNumber },
    .{ .name = "IS-STRING", .func = nativeIsString },
};

inline fn popB(vm: *Vm) !bool {
    return switch (try vm.stack.pop()) {
         .b => |b| b,
         else => error.InvalidType,
    };
}

inline fn peekB(vm: *Vm) !bool {
    const v = try vm.stack.peek();
    return switch (v.*) {
        .b => |b| b,
        else => error.InvalidType,
    };
}

inline fn pushB(vm: *Vm, b: bool) !void {
    try vm.stack.push(.{ .b = b });
}

inline fn replaceB(vm: *Vm, b: bool) !void {
    const v = try vm.stack.peek();
    v.* = .{ .b = b };
}

inline fn popN(vm: *Vm) !i32 {
    return switch (try vm.stack.pop()) {
        .n => |n| n,
        else => error.InvalidType,
    };
}

inline fn peekN(vm: *Vm) !i32 {
    const v = try vm.stack.peek();
    return switch (v.*) {
        .n => |n| n,
        else => error.InvalidType,
    };
}

inline fn pushN(vm: *Vm, n: i32) !void {
    try vm.stack.push(.{ .n = n });
}

inline fn replaceN(vm: *Vm, n: i32) !void {
    const v = try vm.stack.peek();
    v.* = .{ .n = n };
}

// == GENERAL PURPOSE == //

fn nativePrint(vm: *Vm) !void {
    const stdout = std.io.getStdOut().writer();
    try (try vm.stack.pop()).print(stdout);
    try stdout.writeAll("\n");
}

fn nativeAssert(vm: *Vm) !void {
    const a = try popB(vm);
    if (!a)
        return error.AssertFailed;
}

fn nativeEquals(vm: *Vm) !void {
    const a = try vm.stack.pop();
    const b = try vm.stack.pop();
    const res = try a.equals(b);
    try pushB(vm, res);
}

fn nativeTo(vm: *Vm) !void {
    const b = try popN(vm);
    const a = try popN(vm);

    var i: i32 = a;

    if (b > a) {
        while (i <= b) : (i += 1) {
            try pushN(vm, i);
        }
    } else {
        while (i >= b) : (i -= 1) {
            try pushN(vm, i);
        }
    }
}

// == STACK MANIPULATION == //

fn nativeDrop(vm: *Vm) !void {
    try vm.stack.drop();
}

fn nativeDup(vm: *Vm) !void {
    try vm.stack.push((try vm.stack.peek()).*);
}

fn nativeSwap(vm: *Vm) !void {
    const top = try vm.stack.pop();
    const below = try vm.stack.pop();
    try vm.stack.push(top);
    try vm.stack.push(below);
}

fn nativeRot(vm: *Vm) !void {
    const a = try vm.stack.pop();
    const b = try vm.stack.pop();
    const c = try vm.stack.pop();
    try vm.stack.push(b);
    try vm.stack.push(a);
    try vm.stack.push(c);
}

fn nativeOver(vm: *Vm) !void {
    const a = try vm.stack.pop();
    const b = try vm.stack.pop();
    try vm.stack.push(b);
    try vm.stack.push(a);
    try vm.stack.push(b);
}

fn nativeCount(vm: *Vm) !void {
    try pushN(vm, @intCast(vm.stack.count));
}

fn nativeIsEmpty(vm: *Vm) !void {
    try pushB(vm, vm.stack.count == 0);
}

// == BOOLEAN OPERATIONS == //

fn nativeNot(vm: *Vm) !void {
    const b = try popB(vm);
    try pushB(vm, !b);
}

const BooleanBinaryOp = enum {
    @"or",
    @"and",
};

inline fn nativeBooleanBinaryOp(vm: *Vm, comptime op: BooleanBinaryOp) !void {
    const a = try popB(vm);
    const b = try peekB(vm);
    const res = switch (op) {
        .@"or" => a or b,
        .@"and" => a and b,
    };
    try replaceB(vm, res);
}

fn nativeOr(vm: *Vm) !void {
    return nativeBooleanBinaryOp(vm, .@"or");
}

fn nativeAnd(vm: *Vm) !void {
    return nativeBooleanBinaryOp(vm, .@"and");
}

// == NUMBER COMPARATORS == //

const NumberComparisonOp = enum {
    gt,
    ge,
    lt,
    le,
};

inline fn nativeNumberComparisonOp(vm: *Vm, comptime op: NumberComparisonOp) !void {
    const b = try popN(vm);
    const a = try peekN(vm);
    const res = switch (op) {
        .gt => a > b,
        .ge => a >= b,
        .lt => a < b,
        .le => a <= b,
    };
    try replaceB(vm, res);
}

fn nativeGreaterThan(vm: *Vm) !void {
    return nativeNumberComparisonOp(vm, .gt);
}

fn nativeGreaterEqual(vm: *Vm) !void {
    return nativeNumberComparisonOp(vm, .ge);
}

fn nativeLessThan(vm: *Vm) !void {
    return nativeNumberComparisonOp(vm, .lt);
}

fn nativeLessEqual(vm: *Vm) !void {
    return nativeNumberComparisonOp(vm, .le);
}

// == TYPE CHECKS ==

fn nativeIsBoolean(vm: *Vm) !void {
    const v = try vm.stack.peek();
    const res = switch (v.*) {
        .b => true,
        else => false,
    };
    try pushB(vm, res);
}

fn nativeIsNumber(vm: *Vm) !void {
    const v = try vm.stack.peek();
    const res = switch (v.*) {
        .n => true,
        else => false,
    };
    try pushB(vm, res);
}

fn nativeIsString(vm: *Vm) !void {
    const v = try vm.stack.peek();
    const res = switch (v.*) {
        .s => true,
        else => false,
    };
    try pushB(vm, res);
}