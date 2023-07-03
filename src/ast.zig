const std = @import("std");

const vm = @import("./vm.zig");

pub const AST = union(enum) {
    n: i32,
    b: bool,
    id: []const u8,
    @"if": If,
    @"while": []const AST,
    add,
    sub,
    div,
    mul,

    pub const If = struct { if_true: []const AST, if_false: []const AST };

    pub fn compile(
        instructions: *std.ArrayList(vm.Instruction),
        routine: []const AST,
    ) !void {
        for (routine) |c| {
            switch (c) {
                .n => |n| try instructions.append(vm.Instruction{ .psh = vm.Value{ .n = n } }),
                .b => |b| try instructions.append(vm.Instruction{ .psh = vm.Value{ .b = b } }),
                .id => |s| try instructions.append(vm.Instruction{ .cal = s }),
                .@"if" => |s| {
                    try instructions.append(vm.Instruction{ .jif = 0 });
                    const false_jump_index = instructions.items.len - 1;

                    try compile(instructions, s.if_true);

                    try instructions.append(vm.Instruction{ .jmp = 0 });
                    const end_jump_index = instructions.items.len - 1;

                    const false_jump = end_jump_index + 1;
                    try compile(instructions, s.if_false);

                    try instructions.append(.nop);
                    const end_jump = instructions.items.len - 1;

                    instructions.items[false_jump_index] = vm.Instruction{ .jif = false_jump };
                    instructions.items[end_jump_index] = vm.Instruction{ .jmp = end_jump };
                },
                .@"while" => |s| {
                    const start_index = instructions.items.len;
                    try compile(instructions, s);
                    try instructions.append(vm.Instruction{ .jif = 0 });
                    const false_jump_index = instructions.items.len - 1;
                    try instructions.append(vm.Instruction{ .jmp = start_index });
                    const false_jump = instructions.items.len - 1;

                    instructions.items[false_jump_index] = vm.Instruction{ .jif = false_jump };
                },
                .add => try instructions.append(.add),
                .sub => try instructions.append(.sub),
                .div => try instructions.append(.div),
                .mul => try instructions.append(.mul),
            }
        }
    }
};
