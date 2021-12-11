const std = @import("std");
const wasm3 = @import("wasm3");

const kib = 1024;
const mib = 1024 * kib;
const gib = 1024 * mib;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var a = &gpa.allocator;

    var args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    if (args.len < 2) {
        std.log.err("Please provide a wasm file on the command line!\n", .{});
        std.os.exit(1);
    }

    std.log.info("Loading wasm file {s}!\n", .{args[1]});


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

    try mod.linkLibrary("native_helpers", struct {
        pub fn add(_: *std.mem.Allocator, lh: i32, rh: i32, mul: wasm3.SandboxPtr(i32)) callconv(.Inline) i32 {
            mul.write(lh * rh);
            return lh + rh;
        }
        pub fn getArgv0(allocator: *std.mem.Allocator, str: wasm3.SandboxPtr(u8), max_len: u32) callconv(.Inline) u32 {
            var in_buf = str.slice(max_len);

            var arg_iter = std.process.args();
            defer arg_iter.deinit();
            var first_arg = (arg_iter.next(allocator) orelse return 0) catch return 0;
            defer allocator.free(first_arg);

            if (first_arg.len > in_buf.len) return 0;
            std.mem.copy(u8, in_buf, first_arg);

            return @truncate(u32, first_arg.len);
        }
    }, a);

    var start_fn = try rt.findFunction("main");
    start_fn.call(void, .{}) catch |e| switch (e) {
        error.TrapExit => {},
        else => return e,
    };

    var add_five_fn = try rt.findFunction("addFive");
    const num: i32 = 7;
    std.debug.warn("Adding 5 to {d}: got {d}!\n", .{ num, try add_five_fn.call(i32, .{num}) });

    var alloc_fn = try rt.findFunction("allocBytes");
    var print_fn = try rt.findFunction("printStringZ");

    const my_string = "Hello, world!";

    var buffer_np = try alloc_fn.call(wasm3.SandboxPtr(u8), .{@as(u32, my_string.len + 1)});
    var buffer = buffer_np.slice(my_string.len + 1);

    std.debug.warn("Allocated buffer!\n{any}\n", .{buffer});

    std.mem.copy(u8, buffer, my_string);
    buffer[my_string.len] = 0;

    try print_fn.call(void, .{buffer_np});

    var optionally_null_np: ?wasm3.SandboxPtr(u8) = null;
    try print_fn.call(void, .{optionally_null_np});

    try test_globals(a);
}

/// This is in a separate file because I can't find any
/// compiler toolchains that actually work with Wasm globals yet (lol)
/// so we just ship a binary wasm file that works with them
pub fn test_globals(a: *std.mem.Allocator) !void {

    var env = wasm3.Environment.init();
    defer env.deinit();

    var rt = env.createRuntime(1 * kib, null);
    defer rt.deinit();
    errdefer rt.printError();

    var mod_bytes = try std.fs.cwd().readFileAlloc(a, "example/global.wasm", 512 * kib);
    defer a.free(mod_bytes);
    var mod = try env.parseModule(mod_bytes);
    try rt.loadModule(mod);

    var one = mod.findGlobal("one") orelse {
        std.debug.panic("Failed to find global \"one\"\n", .{});
    };
    var some = mod.findGlobal("some") orelse {
        std.debug.panic("Failed to find global \"some\"\n", .{});
    };

    std.debug.warn("'one' value: {d}\n", .{(try one.get()).Float32});
    std.debug.warn("'some' value: {d}\n", .{(try some.get()).Float32});

    std.debug.warn("Trying to set 'one' value to 5.0, should fail.\n", .{});
    
    one.set(.{.Float32 = 5.0}) catch |err| switch(err) {
        wasm3.Error.SettingImmutableGlobal => {
            std.debug.warn("Failed successfully!\n", .{});
        },
        else => {
            std.debug.warn("Unexpected error {any}\n", .{err});
        }
    };
    std.debug.warn("'one' value: {d}\n", .{(try one.get()).Float32});
    if((try one.get()).Float32 != 1.0) {
        std.log.err("Global 'one' has a different value. This is probably a wasm3 bug!\n", .{});
    }

    var some_setter = try rt.findFunction("set_some");
    try some_setter.call(void, .{@as(f32, 25.0)});
    std.debug.warn("'some' value: {d}\n", .{(try some.get()).Float32});
}