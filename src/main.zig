const std = @import("std");
const print = std.debug.print;

const vm = @import("./vm.zig");
const ast = @import("./ast.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const r = [_]ast.AST{
        ast.AST{ .b = true },
        ast.AST{
            .@"if" = ast.AST.If{
                .if_true = &[_]ast.AST{
                    ast.AST{
                        .@"while" = &[_]ast.AST{
                            ast.AST{ .n = 1 },
                            ast.AST{ .id = "PRINT" },
                            ast.AST{ .b = true },
                        },
                    },
                },
                .if_false = &[_]ast.AST{
                    ast.AST{ .n = 0 },
                    ast.AST{ .id = "PRINT" },
                },
            },
        },
    };

    var instructions = std.ArrayList(vm.Instruction).init(allocator);
    defer instructions.deinit();

    try ast.AST.compile(&instructions, &r);
    try instructions.append(.ret);

    const routine = vm.Routine{ .user = instructions.items };

    var routines = std.StringHashMap(vm.Routine).init(allocator);
    try routines.put("PROGRAM", routine);
    var v = try vm.VM.init(&routines);
    v.run() catch |err| {
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
        v.printStacktrace();
    };
}
