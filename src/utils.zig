const std = @import("std");
const print = std.debug.print;

pub fn printSourceDiagnosis(
    name: []const u8,
    line: usize,
    column: usize,
    len: usize,
    routineName: []const u8,
    source: []const u8,
) void {
    const stderr = std.io.getStdErr().writer();

    print(
        "{s}:{}:{}: in {s}\n",
        .{
            name,
            line + 1,
            column + 1,
            routineName,
        },
    );

    printLine(stderr, source, line) catch {};

    for (0..column - len) |_| {
        print(" ", .{});
    }

    for (0..len) |_| {
        print("^", .{});
    }
    print("\n", .{});
}

fn printLine(writer: anytype, buffer: []const u8, line: usize) !void {
    var s: usize = 0;
    var e: usize = 0;
    var l: usize = 0;

    for (buffer, 0..) |c, i| {
        if (c == '\n') {
            l += 1;
            if (l == line) {
                s = i + 1;
                break;
            }
        }
    }

    for (buffer[s..], s..) |c, i| {
        if (c == '\n') {
            e = i;
            break;
        }
    }

    if (e == 0) {
        e = buffer.len;
    }

    try writer.writeAll(buffer[s..e]);
    try writer.writeAll("\n");
}
