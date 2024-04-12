const std = @import("std");

const Vm = @import("./Vm.zig");

pub const routines = [_]Vm.NativeRoutine{
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

// == GENERAL PURPOSE == //

fn nativePrint(vm: *Vm) !void {
    const stdout = std.io.getStdOut().writer();
    try (try vm.stack.pop()).print(stdout);
    try stdout.writeAll("\n");
}

fn nativeAssert(vm: *Vm) !void {
    switch (try vm.stack.pop()) {
        .b => |b| if (!b) return error.AssertFailed,
        else => return error.InvalidType,
    }
}

fn nativeEquals(vm: *Vm) !void {
    const a = try vm.stack.pop();
    const b = try vm.stack.pop();
    try vm.stack.push(.{ .b = try a.equals(b) });
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

// == BOOLEAN OPERATIONS == //

fn nativeNot(vm: *Vm) !void {
    try vm.stack.push(switch (try vm.stack.pop()) {
        .b => |b| .{ .b = !b },
        else => return error.InvalidType,
    });
}

const BooleanBinaryOp = enum {
    @"or",
    @"and",
};

inline fn nativeBooleanBinaryOp(vm: *Vm, comptime op: BooleanBinaryOp) !void {
    const a = switch (try vm.stack.pop()) {
        .b => |b| b,
        else => return error.InvalidType,
    };
    const t = try vm.stack.peek();
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
    const b = switch (try vm.stack.pop()) {
        .n => |n| n,
        else => return error.InvalidType,
    };
    const a = switch (try vm.stack.pop()) {
        .n => |n| n,
        else => return error.InvalidType,
    };
    const res = switch (op) {
        .gt => a > b,
        .ge => a >= b,
        .lt => a < b,
        .le => a <= b,
    };
    try vm.stack.push(Vm.Value{ .b = res });
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
