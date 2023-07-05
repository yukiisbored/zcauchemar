const std = @import("std");

const VM = @import("./VM.zig");

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

    pub const If = struct {
        if_true: []const AST,
        if_false: []const AST,
    };

    pub const Program = struct {
        allocator: std.mem.Allocator,
        routines: std.ArrayList(std.ArrayList(VM.Instruction)),

        pub const Routine = struct {
            name: []const u8,
            ast: []const AST,

            pub fn print(self: Routine, writer: anytype) !void {
                try std.fmt.format(writer, "(routine '{s}' (", .{self.name});
                for (0.., self.ast) |n, x| {
                    try x.print(writer);
                    if (n < self.ast.len - 1) {
                        try writer.writeAll(" ");
                    }
                }
                try writer.writeAll("))");
            }
        };

        pub fn init(allocator: std.mem.Allocator, vm: *VM, routines: []const Routine) !Program {
            var res = Program{
                .allocator = allocator,
                .routines = std.ArrayList(std.ArrayList(VM.Instruction)).init(allocator),
            };

            for (routines) |r| {
                var i = std.ArrayList(VM.Instruction).init(allocator);
                try compile(&i, r.ast);
                try i.append(.ret);
                try vm.addRoutine(r.name, i.items);
                try res.routines.append(i);
            }

            return res;
        }

        pub fn deinit(self: *Program) void {
            for (self.routines.items) |ir| {
                ir.deinit();
            }
            self.routines.deinit();
        }
    };

    pub fn print(self: AST, writer: anytype) !void {
        try switch (self) {
            .n => |n| std.fmt.format(writer, "(n {})", .{n}),
            .b => |b| std.fmt.format(writer, "(b {})", .{b}),
            .id => |i| std.fmt.format(writer, "(id '{s}')", .{i}),
            .@"if" => |i| {
                try writer.writeAll("(if (");
                for (0.., i.if_true) |n, x| {
                    try x.print(writer);
                    if (n < i.if_true.len - 1) {
                        try writer.writeAll(" ");
                    }
                }
                try writer.writeAll(") (");
                for (0.., i.if_false) |n, x| {
                    try x.print(writer);
                    if (n < i.if_false.len - 1) {
                        try writer.writeAll(" ");
                    }
                }
                try writer.writeAll("))");
            },
            .@"while" => |w| {
                try writer.writeAll("(while (");
                for (0.., w) |n, x| {
                    try x.print(writer);
                    if (n < w.len - 1) {
                        try writer.writeAll(" ");
                    }
                }
                try writer.writeAll("))");
            },
            .add => writer.writeAll("(add)"),
            .sub => writer.writeAll("(sub)"),
            .div => writer.writeAll("(div)"),
            .mul => writer.writeAll("(mul)"),
        };
    }

    fn compile(
        instructions: *std.ArrayList(VM.Instruction),
        routine: []const AST,
    ) !void {
        for (routine) |c| {
            switch (c) {
                .n => |n| try instructions.append(VM.Instruction{ .psh = VM.Value{ .n = n } }),
                .b => |b| try instructions.append(VM.Instruction{ .psh = VM.Value{ .b = b } }),
                .id => |s| try instructions.append(VM.Instruction{ .cal = s }),
                .@"if" => |s| {
                    try instructions.append(VM.Instruction{ .jif = 0 });
                    const false_jump_index = instructions.items.len - 1;

                    try compile(instructions, s.if_true);

                    try instructions.append(VM.Instruction{ .jmp = 0 });
                    const end_jump_index = instructions.items.len - 1;

                    const false_jump = end_jump_index + 1;
                    try compile(instructions, s.if_false);

                    try instructions.append(.nop);
                    const end_jump = instructions.items.len - 1;

                    instructions.items[false_jump_index] = VM.Instruction{ .jif = false_jump };
                    instructions.items[end_jump_index] = VM.Instruction{ .jmp = end_jump };
                },
                .@"while" => |s| {
                    const start_index = instructions.items.len;
                    try compile(instructions, s);
                    try instructions.append(VM.Instruction{ .jif = 0 });
                    const false_jump_index = instructions.items.len - 1;
                    try instructions.append(VM.Instruction{ .jmp = start_index });
                    const false_jump = instructions.items.len;

                    instructions.items[false_jump_index] = VM.Instruction{ .jif = false_jump };
                },
                .add => try instructions.append(.add),
                .sub => try instructions.append(.sub),
                .div => try instructions.append(.div),
                .mul => try instructions.append(.mul),
            }
        }
    }
};
