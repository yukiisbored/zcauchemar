const std = @import("std");

const Scanner = @import("./Scanner.zig");
const Vm = @import("./Vm.zig");
const Ast = @import("./Ast.zig");

const Self = @This();

allocator: std.mem.Allocator,
routines: std.ArrayList(Routine),

pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .allocator = allocator,
        .routines = std.ArrayList(Routine).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    for (self.routines.items) |ir| {
        ir.deinit();
    }
    self.routines.deinit();
}

pub fn compile(self: *Self, vm: *Vm, routines: []const Ast.Routine) !void {
    for (routines) |r| {
        var i = try Routine.init(self.allocator);
        try i.compile(r.ast);
        try i.emit(.ret, r.token);
        try vm.addRoutine(r.name, i.instructions.items, i.tokens.items);
        try self.routines.append(i);
    }
}

pub const Routine = struct {
    instructions: std.ArrayList(Vm.Instruction),
    tokens: std.ArrayList(Scanner.Token),

    pub fn init(allocator: std.mem.Allocator) !Routine {
        return Routine{
            .instructions = std.ArrayList(Vm.Instruction).init(allocator),
            .tokens = std.ArrayList(Scanner.Token).init(allocator),
        };
    }

    pub fn deinit(self: *const Routine) void {
        self.instructions.deinit();
        self.tokens.deinit();
    }

    pub fn emit(
        self: *Routine,
        instruction: Vm.Instruction,
        token: Scanner.Token,
    ) !void {
        try self.instructions.append(instruction);
        try self.tokens.append(token);
    }

    pub fn compile(
        self: *Routine,
        routine: []const Ast,
    ) !void {
        for (routine) |c| {
            switch (c.i) {
                .add => try self.emit(.add, c.t),
                .sub => try self.emit(.sub, c.t),
                .div => try self.emit(.div, c.t),
                .mul => try self.emit(.mul, c.t),
                .n => |n| try self.emit(.{ .psh = .{ .n = n } }, c.t),
                .b => |b| try self.emit(.{ .psh = .{ .b = b } }, c.t),
                .s => |s| try self.emit(.{ .psh = .{ .s = s } }, c.t),
                .id => |s| try self.emit(.{ .cal = s }, c.t),
                .@"if" => |s| {
                    try self.emit(.{ .jif = 0 }, c.t);
                    const false_jump_index = self.instructions.items.len - 1;

                    try self.compile(s.if_true);

                    try self.emit(.{ .jmp = 0 }, c.t);
                    const end_jump_index = self.instructions.items.len - 1;

                    const false_jump = end_jump_index + 1;
                    try self.compile(s.if_false);

                    try self.emit(.nop, c.t);

                    const end_jump = self.instructions.items.len - 1;

                    self.instructions.items[false_jump_index] = .{ .jif = false_jump };
                    self.instructions.items[end_jump_index] = .{ .jmp = end_jump };
                },
                .@"while" => |s| {
                    const start_index = self.instructions.items.len;

                    try self.compile(s);
                    try self.emit(.{ .jif = 0 }, c.t);

                    const false_jump_index = self.instructions.items.len - 1;

                    try self.emit(.{ .jmp = start_index }, c.t);

                    const false_jump = self.instructions.items.len;

                    self.instructions.items[false_jump_index] = .{ .jif = false_jump };
                },
            }
        }
    }
};


