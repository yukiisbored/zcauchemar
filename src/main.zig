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
    var v = vm.VM.init(&routines);
    v.run();
    for (v.stack[0..v.stack_top]) |i| {
        switch (i) {
            .n => |n| print("{}\n", .{n}),
        }
    }
}
