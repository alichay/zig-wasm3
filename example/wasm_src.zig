const std = @import("std");

extern "libtest" fn add(a: i32, b: i32, mul: *i32) i32;

extern "libtest" fn getArgv0(str_buf: [*]u8, max_len: u32) u32;

const max_arg_size = 256;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var a = &arena.allocator;

    const a1 = 2;
    const a2 = 6;

    var mul_res: i32 = 0;
    const add_res = add(a1, a2, &mul_res);

    std.debug.warn("{d} + {d} = {d} (multiplied, it's {d}!)\n", .{a1, a2, add_res, mul_res});

    var buf = try a.alloc(u8, max_arg_size);
    var written = getArgv0(buf.ptr, buf.len);
    if(written != 0) {
        std.debug.warn("Got string {s}!\n", .{buf[0..@intCast(usize, written)]});
    } else {
        std.debug.warn("Failed to write string! No bytes written.", .{});
    }

}