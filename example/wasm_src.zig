const std = @import("std");

extern "libtest" fn add(a: i32, b: i32, mul: *i32) i32;

pub fn main() void {
    const a = 5;
    const b = 7;
    var mul: i32 = 0;
    std.debug.warn("Hello world! {d} + {d} = {d} (mul = {d})\n", .{a, b, add(a, b, &mul), mul});
}