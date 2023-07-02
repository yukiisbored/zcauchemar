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
    var frame = vm.Frame{ .routine = &routine, .ip = 0 };
    var ip = std.ArrayList(*vm.Frame).init(allocator);
    try ip.append(&frame);
    var routines = std.StringHashMap(*const vm.Routine).init(allocator);
    try routines.put("PROGRAM", &routine);
    var stack = std.ArrayList(vm.Value).init(allocator);
    var v = vm.VM{ .ip = &ip, .stack = &stack, .routines = &routines };
    try v.run();
}
