const std = @import("std");
const Scanner = @import("./Scanner.zig");

const Self = @This();

i: Inner,
t: Scanner.Token,

pub const Inner = union(enum) {
    n: i32,
    b: bool,
    s: []const u8,
    id: []const u8,
    @"if": If,
    @"while": []const Self,
    add,
    sub,
    div,
    mul,

    pub const If = struct {
        if_true: []const Self,
        if_false: []const Self,
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

pub const Routine = struct {
    name: []const u8,
    ast: []const Self,
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
