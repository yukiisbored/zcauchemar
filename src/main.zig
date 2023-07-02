const std = @import("std");
const print = std.debug.print;

const vm = @import("./vm.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const instructions = [_]vm.Instruction{
        vm.Instruction{ .psh = &vm.Value{ .n = 16 } },
        vm.Instruction{ .psh = &vm.Value{ .n = 32 } },
        .add,
        .ret,
    };
    const routine = vm.Routine{ .user = &instructions };
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
        };
        print("Runtime Error: {s}\n", .{msg});
        v.printStacktrace();
    };
}
