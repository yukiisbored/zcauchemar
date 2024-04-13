const std = @import("std");

pub fn printLine(writer: anytype, buffer: []const u8, lineNumber: usize) !void {
    var lineStart: usize = 0;
    var lineEnd: usize = 0;
    var currentLine: usize = 0;

    for (buffer, 0..) |c, i| {
        if (c == '\n') {
            currentLine += 1;
            if (currentLine == lineNumber) {
                lineStart = i + 1;
                break;
            }
        }
    }

    for (buffer[lineStart..], lineStart..) |c, i| {
        if (c == '\n') {
            lineEnd = i;
            break;
        }
    }

    if (lineEnd == 0) {
        lineEnd = buffer.len;
    }

    try writer.writeAll(buffer[lineStart..lineEnd]);
    try writer.writeAll("\n");
}