const std = @import("std");

const Scanner = @import("./Scanner.zig");
const AST = @import("./ast.zig").AST;

const Self = @This();

arena: std.heap.ArenaAllocator,

scanner: *Scanner,
routines: *std.ArrayList(AST.Program.Routine),

current: Scanner.Token,
previous: Scanner.Token,

errorToken: ?*const Scanner.Token,
errorMessage: ?[]const u8,

pub const Error = error{
    ParserError,
} || std.mem.Allocator.Error;

fn errorAt(self: *Self, token: *const Scanner.Token, message: []const u8) Error!void {
    self.errorToken = token;
    self.errorMessage = message;

    return Error.ParserError;
}

fn @"error"(self: *Self, message: []const u8) Error!void {
    try self.errorAt(&self.previous, message);
}

fn errorAtCurrent(self: *Self, message: []const u8) Error!void {
    try self.errorAt(&self.current, message);
}

fn advance(self: *Self) Error!void {
    self.previous = self.current;

    while (true) {
        self.current = self.scanner.scan();
        if (self.current.type != .@"error") break;

        try self.errorAtCurrent(self.current.str);
    }
}

fn consume(self: *Self, @"type": Scanner.TokenType, message: []const u8) Error!void {
    if (self.current.type == @"type") {
        try self.advance();
        return;
    }

    try self.errorAtCurrent(message);
}

fn check(self: *Self, @"type": Scanner.TokenType) bool {
    return self.current.type == @"type";
}

fn match(self: *Self, @"type": Scanner.TokenType) Error!bool {
    if (!self.check(@"type")) return false;
    try self.advance();
    return true;
}

fn whileBlock(self: *Self, target: *std.ArrayList(AST)) Error!void {
    const allocator = self.arena.allocator();

    var commands = std.ArrayList(AST).init(allocator);

    while (!self.check(.@"while")) {
        try self.command(&commands);
    }

    try self.consume(.@"while", "Expected WHILE");

    try target.append(AST{ .@"while" = commands.items });
}

fn ifBlock(self: *Self, target: *std.ArrayList(AST)) Error!void {
    const allocator = self.arena.allocator();

    var if_true = std.ArrayList(AST).init(allocator);
    while (!(self.check(.then) or self.check(.@"else"))) {
        try self.command(&if_true);
    }

    var if_false = std.ArrayList(AST).init(allocator);

    if (try self.match(.@"else")) {
        while (!(self.check(.then))) {
            try self.command(&if_false);
        }
    }

    try self.consume(.then, "Expected THEN");

    try target.append(
        AST{
            .@"if" = AST.If{
                .if_true = if_true.items,
                .if_false = if_false.items,
            },
        },
    );
}

fn number(self: *Self, target: *std.ArrayList(AST)) Error!void {
    try target.append(AST{ .n = std.fmt.parseInt(i32, self.previous.str, 10) catch unreachable });
}

fn arithmetic(self: *Self, target: *std.ArrayList(AST)) Error!void {
    try target.append(
        switch (self.previous.type) {
            .plus => .add,
            .minus => .sub,
            .slash => .div,
            .star => .mul,
            else => unreachable,
        },
    );
}

fn boolean(self: *Self, target: *std.ArrayList(AST)) Error!void {
    try target.append(
        switch (self.previous.type) {
            .true => AST{ .b = true },
            .false => AST{ .b = false },
            else => unreachable,
        },
    );
}

fn string(self: *Self, target: *std.ArrayList(AST)) Error!void {
    try target.append(AST{ .s = self.previous.str[1 .. self.previous.str.len - 1] });
}

fn identifier(self: *Self, target: *std.ArrayList(AST)) Error!void {
    try target.append(AST{ .id = self.previous.str });
}

fn command(self: *Self, target: *std.ArrayList(AST)) Error!void {
    if (try self.match(.do)) {
        try self.whileBlock(target);
    } else if (try self.match(.@"if")) {
        try self.ifBlock(target);
    } else if (try self.match(.number)) {
        try self.number(target);
    } else if (try self.match(.plus) or try self.match(.minus) or try self.match(.slash) or try self.match(.star)) {
        try self.arithmetic(target);
    } else if (try self.match(.true) or try self.match(.false)) {
        try self.boolean(target);
    } else if (try self.match(.string)) {
        try self.string(target);
    } else if (try self.match(.identifier)) {
        try self.identifier(target);
    } else {
        try self.errorAtCurrent("Unexpected syntax");
    }
}

fn routine(self: *Self) Error!void {
    const allocator = self.arena.allocator();

    try self.consume(.routine, "Expected routine");

    const routineName = self.previous.str;
    var commands = std.ArrayList(AST).init(allocator);

    while (!(self.check(.routine) or self.check(.eof))) {
        try self.command(&commands);
    }

    try self.routines.append(
        AST.Program.Routine{
            .name = routineName,
            .ast = commands.items,
        },
    );
}

pub fn init(
    allocator: std.mem.Allocator,
    scanner: *Scanner,
    routines: *std.ArrayList(AST.Program.Routine),
) Self {
    const initToken =
        Scanner.Token{
        .type = .eof,
        .str = "",
        .line = 0,
    };

    return Self{
        .arena = std.heap.ArenaAllocator.init(allocator),

        .scanner = scanner,
        .routines = routines,

        .previous = initToken,
        .current = initToken,

        .errorToken = null,
        .errorMessage = null,
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn parse(self: *Self) Error!void {
    try self.advance();

    while (!try self.match(.eof)) {
        try self.routine();
    }

    try self.consume(.eof, "Expected EOF");
}
