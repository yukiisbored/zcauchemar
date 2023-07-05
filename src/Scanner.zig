const std = @import("std");

const Self = @This();

corpus: []const u8,
start: usize,
current: usize,
line: usize,

pub const TokenType = enum {
    // Single character tokens
    plus,
    minus,
    star,
    slash,
    colon,

    // Literals
    identifier,
    number,

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

pub fn init(corpus: []const u8) Self {
    return Self{
        .corpus = corpus,
        .start = 0,
        .current = 0,
        .line = 0,
    };
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return c >= 'A' and c <= 'Z';
}

fn isAtEnd(self: *Self) bool {
    return self.current >= self.corpus.len;
}

fn advance(self: *Self) u8 {
    self.current += 1;
    return self.corpus[self.current - 1];
}

fn peek(self: *Self) u8 {
    if (self.isAtEnd()) return 0;
    return self.corpus[self.current];
}

fn peekNext(self: *Self) u8 {
    if (self.isAtEnd() or self.current + 1 >= self.corpus.len) return 0;
    return self.corpus[self.current + 1];
}

fn match(self: *Self, c: u8) bool {
    if (self.isAtEnd()) return false;
    if (self.peek() != c) return false;
    self.current += 1;
    return true;
}

fn makeToken(self: *Self, @"type": TokenType) Token {
    return Token{
        .type = @"type",
        .str = self.corpus[self.start..self.current],
        .line = self.line,
    };
}

fn errorToken(self: *Self, message: []const u8) Token {
    return Token{
        .type = .@"error",
        .str = message,
        .line = self.line,
    };
}

fn skipWhitespace(self: *Self) void {
    while (true) {
        const c = self.peek();
        switch (c) {
            ' ', '\r', '\t' => _ = self.advance(),
            '\n' => {
                self.line += 1;
                _ = self.advance();
            },
            '/' => {
                if (self.peekNext() == '/') {
                    while (self.peek() != '\n' and !self.isAtEnd()) _ = self.advance();
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}

fn checkKeyword(
    self: *Self,
    start: usize,
    rest: []const u8,
    @"type": TokenType,
) TokenType {
    const startPos = self.start + start;
    if (self.current - self.start == start + rest.len and
        std.mem.eql(u8, self.corpus[startPos .. startPos + rest.len], rest))
    {
        return @"type";
    }

    return .identifier;
}

fn identifierType(self: *Self) TokenType {
    return switch (self.corpus[self.start]) {
        'T' => switch (self.corpus[self.start + 1]) {
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
    while (isAlpha(self.peek()) or self.peek() == '-') _ = self.advance();
    return self.makeToken(self.identifierType());
}

fn number(self: *Self) Token {
    while (isDigit(self.peek())) _ = self.advance();
    return self.makeToken(.number);
}

pub fn scan(self: *Self) Token {
    self.skipWhitespace();

    self.start = self.current;

    if (self.isAtEnd()) return self.makeToken(.eof);

    const c = self.advance();

    if (isAlpha(c)) return self.identifier();
    if (isDigit(c)) return self.number();

    return switch (c) {
        '+' => self.makeToken(.plus),
        '-' => self.makeToken(.minus),
        '*' => self.makeToken(.star),
        '/' => self.makeToken(.slash),
        ':' => self.makeToken(.colon),
        else => self.errorToken("Unexpected character"),
    };
}
