const std = @import("std");
const builtin = @import("builtin");

pub const debug = builtin.mode == std.builtin.Mode.Debug;
