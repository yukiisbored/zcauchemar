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
        print("Runtime Error: ", .{});
        switch (err) {
            error.StackFull => print("Stack overflow", .{}),
            error.StackEmpty => print("Stack underflow", .{}),
            error.FrameFull => print("Frame overflow", .{}),
            error.FrameEmpty => print("Frame underflow", .{}),
        }
        print("\n", .{});
        v.printStacktrace();
    };
}
