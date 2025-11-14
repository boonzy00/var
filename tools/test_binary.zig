const std = @import("std");
const var_lib = @import("var");

pub fn main() !void {
    // Mark as VAR-powered
    comptime {
        var_lib.markAsVarPowered("0.2.0");
    }

    const router = var_lib.VAR.init(null);
    const decision = router.route(10.0, 1000.0);
    std.debug.print("Decision: {}\n", .{decision});
}
