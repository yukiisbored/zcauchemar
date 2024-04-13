const std = @import("std");

const Scanner = @import("./Scanner.zig");
const Vm = @import("./Vm.zig");

pub fn compile(
    instructions: *std.ArrayList(Vm.Instruction),
    tokens: *std.ArrayList(Scanner.Token),
    routine: []const Ast,
) !void {
    for (routine) |c| {
        switch (c.i) {
            .n => |n| try instructions.append(Vm.Instruction{ .psh = Vm.Value{ .n = n } }),
            .b => |b| try instructions.append(Vm.Instruction{ .psh = Vm.Value{ .b = b } }),
            .s => |s| try instructions.append(Vm.Instruction{ .psh = Vm.Value{ .s = s } }),
            .id => |s| try instructions.append(Vm.Instruction{ .cal = s }),
            .@"if" => |s| {
                try instructions.append(Vm.Instruction{ .jif = 0 });
                try tokens.append(c.t);
                const false_jump_index = instructions.items.len - 1;

                try compile(instructions, tokens, s.if_true);

                try instructions.append(Vm.Instruction{ .jmp = 0 });
                try tokens.append(c.t);
                const end_jump_index = instructions.items.len - 1;

                const false_jump = end_jump_index + 1;
                try compile(instructions, tokens, s.if_false);

                try instructions.append(.nop);
                try tokens.append(c.t);
                const end_jump = instructions.items.len - 1;

                instructions.items[false_jump_index] = Vm.Instruction{ .jif = false_jump };
                instructions.items[end_jump_index] = Vm.Instruction{ .jmp = end_jump };
            },
            .@"while" => |s| {
                const start_index = instructions.items.len;
                try compile(instructions, tokens, s);
                try instructions.append(Vm.Instruction{ .jif = 0 });
                try tokens.append(c.t);
                const false_jump_index = instructions.items.len - 1;
                try instructions.append(Vm.Instruction{ .jmp = start_index });
                try tokens.append(c.t);
                const false_jump = instructions.items.len;

                instructions.items[false_jump_index] = Vm.Instruction{ .jif = false_jump };
            },
            .add => try instructions.append(.add),
            .sub => try instructions.append(.sub),
            .div => try instructions.append(.div),
            .mul => try instructions.append(.mul),
        }
        switch (c.i) {
            .n, .b, .s, .id, .add, .sub, .div, .mul => try tokens.append(c.t),
            else => {}
        }
    }
}

pub const Program = struct {
    allocator: std.mem.Allocator,
    routines: std.ArrayList(CompiledRoutine),

    pub const Routine = struct {
        name: []const u8,
        ast: []const Ast,
        token: Scanner.Token,

        pub fn print(self: Routine, writer: anytype) !void {
            try std.fmt.format(writer, "(routine '{s}' (", .{self.name});
            for (0.., self.ast) |n, x| {
                try x.i.print(writer);
                if (n < self.ast.len - 1) {
                    try writer.writeAll(" ");
                }
            }
            try writer.writeAll("))");
        }
    };

    pub const CompiledRoutine = struct {
        instructions: std.ArrayList(Vm.Instruction),
        tokens: std.ArrayList(Scanner.Token),

        pub fn init(allocator: std.mem.Allocator) !CompiledRoutine {
            return CompiledRoutine{
               .instructions = std.ArrayList(Vm.Instruction).init(allocator),
               .tokens = std.ArrayList(Scanner.Token).init(allocator),
            };
        }

        pub fn deinit(self: *const CompiledRoutine) void {
            self.instructions.deinit();
            self.tokens.deinit();
        }
    };

    pub fn init(allocator: std.mem.Allocator, vm: *Vm, routines: []const Routine) !Program {
        var res = Program{
            .allocator = allocator,
            .routines = std.ArrayList(CompiledRoutine).init(allocator),
        };

        for (routines) |r| {
            var i = try CompiledRoutine.init(allocator);
            try compile(&i.instructions, &i.tokens, r.ast);
            try i.instructions.append(.ret);
            try i.tokens.append(r.token);
            try vm.addRoutine(r.name, i.instructions.items, i.tokens.items);
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

pub const Ast = struct {
    i: Inner,
    t: Scanner.Token,

    pub const Inner = union(enum) {
        n: i32,
        b: bool,
        s: []const u8,
        id: []const u8,
        @"if": If,
        @"while": []const Ast,
        add,
        sub,
        div,
        mul,

        pub const If = struct {
            if_true: []const Ast,
            if_false: []const Ast,
        };

        pub fn print(self: Inner, writer: anytype) !void {
            try switch (self) {
                .n => |n| std.fmt.format(writer, "(n {})", .{n}),
                .b => |b| std.fmt.format(writer, "(b {})", .{b}),
                .s => |s| std.fmt.format(writer, "(s '{s}')", .{s}),
                .id => |i| std.fmt.format(writer, "(id '{s}')", .{i}),
                .@"if" => |i| {
                    try writer.writeAll("(if (");
                    for (0.., i.if_true) |n, x| {
                        try x.i.print(writer);
                        if (n < i.if_true.len - 1) {
                            try writer.writeAll(" ");
                        }
                    }
                    try writer.writeAll(") (");
                    for (0.., i.if_false) |n, x| {
                        try x.i.print(writer);
                        if (n < i.if_false.len - 1) {
                            try writer.writeAll(" ");
                        }
                    }
                    try writer.writeAll("))");
                },
                .@"while" => |w| {
                    try writer.writeAll("(while (");
                    for (0.., w) |n, x| {
                        try x.i.print(writer);
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
    };
};
