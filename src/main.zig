const std = @import("std");
const print = std.debug.print;

const VM = @import("./VM.zig");
const AST = @import("./ast.zig").AST;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) @panic("Memory leak detected");
    }

    var vm = try VM.init(allocator);
    defer vm.deinit();

    const routines = [_]AST.Program.Routine{
        AST.Program.Routine{
            .name = "PROGRAM",
            .ast = &[_]AST{
                AST{ .b = true },
                AST{
                    .@"if" = AST.If{
                        .if_true = &[_]AST{
                            AST{
                                .@"while" = &[_]AST{
                                    AST{ .n = 1 },
                                    AST{ .id = "PRINT" },
                                    AST{ .b = true },
                                },
                            },
                        },
                        .if_false = &[_]AST{
                            AST{ .n = 0 },
                            AST{ .id = "PRINT" },
                        },
                    },
                },
            },
        },
    };

    var program = try AST.Program.init(allocator, &vm, &routines);
    defer program.deinit();

    vm.run() catch |err| {
        const msg = switch (err) {
            error.Overflow => "Stack overflow",
            error.Underflow => "Stack underflow",
            error.InvalidType => "Invalid type",
            error.UnknownRoutine => "Unknown routine",
            else => |e| return e,
        };
        print("Runtime Error: {s}\n", .{msg});
        vm.printStacktrace();
    };
}
