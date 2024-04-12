const std = @import("std");
const print = std.debug.print;

const Vm = @import("./Vm.zig");
const Ast = @import("./ast.zig").Ast;
const Scanner = @import("./Scanner.zig");
const Parser = @import("./Parser.zig");
const debug = @import("./constants.zig").debug;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) @panic("Memory leak detected");
    }

    const stderr = std.io.getStdErr();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        try std.fmt.format(stderr.writer(), "Usage: {s} CAUCHEMAR-FILE\n", .{args[0]});
        return std.process.exit(1);
    }

    const path = args[1];
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    const source = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
    defer allocator.free(source);

    if (debug) {
        print("=== SOURCE ===\n{s}\n", .{source});
    }

    var routines = std.ArrayList(Ast.Program.Routine).init(allocator);
    defer routines.deinit();

    var scanner = Scanner.init(source);
    var parser = Parser.init(allocator, &scanner, &routines);
    errdefer parser.deinit();

    var fail = false;

    if (debug) {
        print("=== TO AST ===\n", .{});
    }

    parser.parse() catch |err| switch (err) {
        error.ParserError => {
            const token = parser.error_token orelse unreachable;
            const message = parser.error_message orelse unreachable;

            print("Error on line {}, column {}", .{token.line + 1, token.column + 1});

            if (token.type == .eof) {
                print(" at end", .{});
            } else if (token.type == .@"error") {
                // Do nothing.
            } else {
                print(" at '{s}'", .{token.str});
            }

            print(": {s}\n", .{message});
            fail = true;
        },
        else => |e| return e,
    };

    if (debug) {
        print("=== AST ===\n", .{});
        for (routines.items) |r| {
            try r.print(stderr.writer());
            try stderr.writeAll("\n");
        }
    }

    if (fail) {
        parser.deinit();
        return;
    }

    if (debug) {
        print("=== VM INIT ===\n", .{});
    }

    var vm = try Vm.init(allocator);
    defer vm.deinit();

    if (debug) {
        print("=== TO BYTECODE ===\n", .{});
    }

    var program = try Ast.Program.init(allocator, &vm, routines.items);
    defer program.deinit();

    // We don't need the Ast anymore.
    parser.deinit();

    if (debug) {
        print("=== BYTECODE ===\n", .{});
        vm.dumpBytecode();
        print("=== VM START ===\n", .{});
    }

    vm.run() catch |err| {
        const msg = switch (err) {
            error.Overflow => "Stack overflow",
            error.Underflow => "Stack underflow",
            error.InvalidType => "Invalid type",
            error.UnknownRoutine => "Unknown routine",
            error.MissingEntrypoint => "Missing entrypoint",
            error.AssertFailed => "Assertion failure",
            else => |e| return e,
        };
        print("Runtime Error: {s}\n", .{msg});
        vm.printStacktrace(true);
    };
}
