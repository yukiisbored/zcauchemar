const std = @import("std");
const print = std.debug.print;

const VM = @import("./VM.zig");
const AST = @import("./ast.zig").AST;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const r = [_]AST{
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
    };

    var instructions = std.ArrayList(VM.Instruction).init(allocator);
    defer instructions.deinit();

    try AST.compile(&instructions, &r);
    try instructions.append(.ret);

    const routine = VM.Routine{ .user = instructions.items };

    var routines = std.StringHashMap(VM.Routine).init(allocator);
    try routines.put("PROGRAM", routine);
    var vm = try VM.init(&routines);
    vm.run() catch |err| {
        const msg = switch (err) {
            error.StackFull => "Stack overflow",
            error.StackEmpty => "Stack underflow",
            error.FrameFull => "Frame full",
            error.FrameEmpty => "Frame underflow",
            error.InvalidType => "Invalid type",
            error.UnknownRoutine => "Unknown routine",
            else => |e| return e,
        };
        print("Runtime Error: {s}\n", .{msg});
        vm.printStacktrace();
    };
}
