const std = @import("std");
const wasm3 = @import("wasm3");

pub fn main() !void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var a = &gpa.allocator;

    var args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    if(args.len < 2) {
        std.log.err("Please provide a wasm file on the command line!\n", .{});
        std.os.exit(1);
    }

    std.log.info("Loading wasm file {s}!\n", .{args[1]});

    const kib = 1024;
    const mib = 1024 * kib;
    const gib = 1024 * mib;

    var env = wasm3.Environment.init();
    defer env.deinit();

    var rt = env.createRuntime(16 * kib, null);
    defer rt.deinit();
    errdefer rt.printError();

    var mod_bytes = try std.fs.cwd().readFileAlloc(a, args[1], 512 * kib);
    defer a.free(mod_bytes);
    var mod = try env.parseModule(mod_bytes);
    try rt.loadModule(mod);
    try mod.linkWasi();

    var add = try rt.findFunction("_start");
    try mod.linkRawFunction("libtest", "add", struct{pub fn add(lh: i32, rh: i32, mul: wasm3.NativePtr(i32)) i32 {
        mul.write(lh * rh);
        return lh + rh;
    }}.add, {});
    add.call(.{}) catch |e| switch(e) {
        error.TrapExit => {},
        else => return e,
    };
}

export fn getrandom(buf: [*c]u8, len: usize, flags: c_uint) i64 {
    std.os.getrandom(buf[0..len]) catch return 0;
    return @intCast(i64, len);
}