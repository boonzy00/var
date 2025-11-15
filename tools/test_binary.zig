const std = @import("std");
const var_lib = @import("var");

pub fn main() !void {
    // Mark as VAR-powered
    comptime {
        // Branding stripped in v1.0 transplant
    }

    const router = var_lib.VAR.init(null);
    const decision = router.route(10.0, 1000.0);
    std.debug.print("Decision: {}\n", .{decision});
}
