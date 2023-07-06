const std = @import("std");
const print = std.debug.print;

const VM = @import("./VM.zig");
const AST = @import("./ast.zig").AST;
const Scanner = @import("./Scanner.zig");
const Parser = @import("./Parser.zig");
const debug = @import("./constants.zig").debug;

pub fn main() !void {
    const stderr = std.io.getStdErr();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) @panic("Memory leak detected");
    }

    var routines = std.ArrayList(AST.Program.Routine).init(allocator);
    defer routines.deinit();

    // TODO: Load from file
    const source =
        \\;; Prints zero
        \\PRINT-ZERO:
        \\    0 PRINT
        \\
        \\;; Basic arthimetic
        \\BASIC-ARITHMETIC:
        \\    1 2 + 3 * 4 /
        \\
        \\;; Truth program
        \\TRUTH-PROGRAM:
        \\    IF DO 1 PRINT TRUE WHILE
        \\    ELSE 0 PRINT THEN
        \\
        \\;; Entrypoint
        \\PROGRAM:
        \\    PRINT-ZERO                        ; Prints zero
        \\
        \\    BASIC-ARITHMETIC                  ; Perform basic math
        \\    TRUE IF TRUE PRINT THEN           ; Prints true if result is greater than 1
        \\
        \\    FALSE TRUTH-PROGRAM               ; Run truth program with "FALSE" as input
    ;

    if (debug) {
        print("=== SOURCE ===\n{s}\n", .{source});
    }

    var scanner = Scanner.init(source);
    var parser = Parser.init(allocator, &scanner, &routines);
    errdefer parser.deinit();

    var fail = false;

    if (debug) {
        print("=== TO AST ===\n", .{});
    }

    parser.parse() catch |err| switch (err) {
        error.ParserError => {
            const token = parser.errorToken orelse unreachable;
            const message = parser.errorMessage orelse unreachable;

            print("Error on line {}", .{token.line});

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

    var vm = try VM.init(allocator);
    defer vm.deinit();

    if (debug) {
        print("=== TO BYTECODE ===\n", .{});
    }

    var program = try AST.Program.init(allocator, &vm, routines.items);
    defer program.deinit();

    // We don't need the AST anymore.
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
