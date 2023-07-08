const std = @import("std");

const Self = @This();

source: []const u8,
start: usize,
current: usize,
line: usize,

pub const TokenType = enum {
    // Single character tokens
    plus,
    minus,
    star,
    slash,

    // Literals
    routine,
    identifier,
    number,
    string,

    // Keywords
    true,
    false,

    do,
    @"while",

    @"if",
    @"else",
    then,

    // Signals
    @"error",
    eof,
};

pub const Token = struct {
    type: TokenType,
    str: []const u8,
    line: usize,
};

pub fn init(source: []const u8) Self {
    return Self{
        .source = source,
        .start = 0,
        .current = 0,
        .line = 0,
    };
}

// === HELPER FUNCTIONS === //

inline fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

inline fn isAlpha(c: u8) bool {
    return c >= 'A' and c <= 'Z';
}

inline fn isAtEnd(self: *Self) bool {
    return self.current >= self.source.len;
}

inline fn forward(self: *Self) void {
    self.current += 1;
}

inline fn advance(self: *Self) u8 {
    self.forward();
    return self.source[self.current - 1];
}

inline fn peek(self: *Self) u8 {
    if (self.isAtEnd()) {
        return 0;
    }
    return self.source[self.current];
}

inline fn peekNext(self: *Self) u8 {
    if (self.isAtEnd() or self.current + 1 >= self.source.len) {
        return 0;
    }
    return self.source[self.current + 1];
}

inline fn match(self: *Self, c: u8) bool {
    if (self.isAtEnd() or self.peek() != c) {
        return false;
    }
    self.current += 1;
    return true;
}

inline fn makeToken(self: *Self, @"type": TokenType) Token {
    return Token{
        .type = @"type",
        .str = self.source[self.start..self.current],
        .line = self.line,
    };
}

inline fn errorToken(self: *Self, message: []const u8) Token {
    return Token{
        .type = .@"error",
        .str = message,
        .line = self.line,
    };
}

inline fn checkKeyword(
    self: *Self,
    start: usize,
    rest: []const u8,
    @"type": TokenType,
) TokenType {
    const startPos = self.start + start;
    if (self.current - self.start == start + rest.len and
        std.mem.eql(u8, self.source[startPos .. startPos + rest.len], rest))
    {
        return @"type";
    }

    return .identifier;
}

// === LEXER === //

fn skipWhitespace(self: *Self) void {
    while (true) {
        const c = self.peek();
        switch (c) {
            ' ', '\r', '\t' => self.forward(),
            '\n' => {
                self.line += 1;
                self.forward();
            },
            ';' => {
                while (self.peek() != '\n' and !self.isAtEnd()) {
                    self.forward();
                }
            },
            else => return,
        }
    }
}

fn identifierType(self: *Self) TokenType {
    return switch (self.source[self.start]) {
        'T' => switch (self.source[self.start + 1]) {
            'H' => self.checkKeyword(2, "EN", .then),
            'R' => self.checkKeyword(2, "UE", .true),
            else => .identifier,
        },
        'F' => self.checkKeyword(1, "ALSE", .false),

        'D' => self.checkKeyword(1, "O", .do),
        'W' => self.checkKeyword(1, "HILE", .@"while"),

        'I' => self.checkKeyword(1, "F", .@"if"),
        'E' => self.checkKeyword(1, "LSE", .@"else"),
        else => .identifier,
    };
}

fn identifier(self: *Self) Token {
    while (isAlpha(self.peek()) or self.peek() == '-') {
        self.forward();
    }

    if (self.peek() == ':') {
        const res = self.makeToken(.routine);
        self.forward();
        return res;
    }
    return self.makeToken(self.identifierType());
}

fn number(self: *Self) Token {
    while (isDigit(self.peek()) or self.peek() == '-') {
        self.forward();
    }

    return self.makeToken(.number);
}

fn string(self: *Self) Token {
    while (self.peek() != '"' and !self.isAtEnd()) {
        if (self.peek() == '\n') {
            self.line += 1;
        }

        self.forward();
    }

    if (self.isAtEnd()) {
        return self.errorToken("Unterminated string");
    }

    self.forward();

    return self.makeToken(.string);
}

pub fn scan(self: *Self) Token {
    self.skipWhitespace();

    self.start = self.current;

    if (self.isAtEnd()) {
        return self.makeToken(.eof);
    }

    const c = self.advance();

    if (isAlpha(c)) {
        return self.identifier();
    }

    if (isDigit(c)) {
        return self.number();
    }

    return switch (c) {
        '+' => self.makeToken(.plus),
        '-' => {
            if (isDigit(self.peek())) {
                return self.number();
            }
            return self.makeToken(.minus);
        },
        '*' => self.makeToken(.star),
        '/' => self.makeToken(.slash),
        '"' => self.string(),
        else => self.errorToken("Unexpected character"),
    };
}
