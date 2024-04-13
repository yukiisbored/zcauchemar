const std = @import("std");

const Scanner = @import("./Scanner.zig");
const compiler = @import("./compiler.zig");
const Ast = compiler.Ast;
const Program = compiler.Program;


const Self = @This();

arena: std.heap.ArenaAllocator,

scanner: *Scanner,
routines: *std.ArrayList(Program.Routine),

current: Scanner.Token,
previous: Scanner.Token,

routine_name: []const u8,

error_token: ?*const Scanner.Token,
error_message: ?[]const u8,

pub const Error = error{
    ParserError,
} || std.mem.Allocator.Error;

pub fn init(
    allocator: std.mem.Allocator,
    scanner: *Scanner,
    routines: *std.ArrayList(Program.Routine),
) Self {
    const initToken = Scanner.Token{
        .type = .eof,
        .str = "",
        .line = 0,
        .column = 0,
    };

    return Self{
        .arena = std.heap.ArenaAllocator.init(allocator),

        .scanner = scanner,
        .routines = routines,

        .previous = initToken,
        .current = initToken,

        .routine_name = "",

        .error_token = null,
        .error_message = null,
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

// == HELPER FUNCTIONS == //

inline fn errorAt(self: *Self, token: *const Scanner.Token, message: []const u8) Error!void {
    self.error_token = token;
    self.error_message = message;

    return Error.ParserError;
}

inline fn @"error"(self: *Self, message: []const u8) Error!void {
    try self.errorAt(&self.previous, message);
}

inline fn errorAtCurrent(self: *Self, message: []const u8) Error!void {
    try self.errorAt(&self.current, message);
}

inline fn advance(self: *Self) Error!void {
    self.previous = self.current;

    while (true) {
        self.current = self.scanner.scan();

        if (self.current.type != .@"error") {
            break;
        }

        try self.errorAtCurrent(self.current.str);
    }
}

inline fn consume(self: *Self, @"type": Scanner.TokenType, message: []const u8) Error!void {
    if (self.current.type == @"type") {
        try self.advance();
        return;
    }

    try self.errorAtCurrent(message);
}

inline fn check(self: *Self, @"type": Scanner.TokenType) bool {
    return self.current.type == @"type";
}

inline fn match(self: *Self, @"type": Scanner.TokenType) Error!bool {
    if (!self.check(@"type")) {
        return false;
    }

    try self.advance();

    return true;
}

// == GRAMMAR == //

fn whileBlock(self: *Self, target: *std.ArrayList(Ast)) Error!void {
    const allocator = self.arena.allocator();

    try self.advance();
    const t = self.previous;

    var commands = std.ArrayList(Ast).init(allocator);

    while (!self.check(.@"while")) {
        try self.command(&commands, "Expected command or WHILE");
    }

    try self.advance();

    try target.append(Ast{ .i = .{ .@"while" = commands.items }, .t = t });
}

fn ifBlock(self: *Self, target: *std.ArrayList(Ast)) Error!void {
    const allocator = self.arena.allocator();

    try self.advance();
    const t = self.previous;

    var if_true = std.ArrayList(Ast).init(allocator);
    while (!(self.check(.then) or self.check(.@"else"))) {
        try self.command(&if_true, "Expected command, THEN, or ELSE");
    }

    var if_false = std.ArrayList(Ast).init(allocator);

    if (try self.match(.@"else")) {
        while (!(self.check(.then))) {
            try self.command(&if_false, "Expected command or THEN");
        }
    }

    try self.advance();

    try target.append(
        Ast{
            .i = .{
                .@"if" = Ast.Inner.If{
                    .if_true = if_true.items,
                    .if_false = if_false.items,
                },
            },
            .t = t,
        },
    );
}

fn number(self: *Self, target: *std.ArrayList(Ast)) Error!void {
    try self.advance();
    try target.append(Ast{
        .i = .{ .n = std.fmt.parseInt(i32, self.previous.str, 10) catch unreachable },
        .t = self.previous,
    });
}

fn arithmetic(self: *Self, target: *std.ArrayList(Ast)) Error!void {
    try self.advance();
    try target.append(Ast{
        .i = switch (self.previous.type) {
            .plus => .add,
            .minus => .sub,
            .slash => .div,
            .star => .mul,
            else => unreachable,
        },
        .t = self.previous,
    });
}

fn boolean(self: *Self, target: *std.ArrayList(Ast)) Error!void {
    try self.advance();
    try target.append(Ast{
        .i = switch (self.previous.type) {
            .true => .{ .b = true },
            .false => .{ .b = false },
            else => unreachable,
        },
        .t = self.previous,
    });
}

fn string(self: *Self, target: *std.ArrayList(Ast)) Error!void {
    try self.advance();
    try target.append(Ast{
        .i = .{ .s = self.previous.str[1 .. self.previous.str.len - 1] },
        .t = self.previous,
    });
}

fn identifier(self: *Self, target: *std.ArrayList(Ast)) Error!void {
    try self.advance();
    try target.append(Ast{
        .i = .{ .id = self.previous.str },
        .t = self.previous,
    });
}

fn command(self: *Self, target: *std.ArrayList(Ast), message: []const u8) Error!void {
    switch (self.current.type) {
        .do => try self.whileBlock(target),
        .@"if" => try self.ifBlock(target),
        .number => try self.number(target),
        .plus, .minus, .slash, .star => try self.arithmetic(target),
        .true, .false => try self.boolean(target),
        .string => try self.string(target),
        .identifier => try self.identifier(target),
        inline else => try self.errorAtCurrent(message),
    }
}

fn routine(self: *Self) Error!void {
    const allocator = self.arena.allocator();

    try self.consume(.routine, "Expected routine");

    const routine_name = self.previous.str;
    self.routine_name = routine_name;

    var commands = std.ArrayList(Ast).init(allocator);

    while (!(self.check(.routine) or self.check(.eof))) {
        try self.command(&commands, "Expected command, routine, or eof");
    }

    try self.routines.append(
        Program.Routine{
            .name = routine_name,
            .ast = commands.items,
        },
    );
}

pub fn parse(self: *Self) Error!void {
    try self.advance();

    while (!try self.match(.eof)) {
        try self.routine();
    }

    try self.consume(.eof, "Expected eof");
}
