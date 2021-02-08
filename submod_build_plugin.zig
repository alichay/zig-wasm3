const std = @import("std");
const root = @import("root");

/// Queues a build job for the C code of Wasm3.
/// This builds a static library that depends on libc, so make sure to link that into your exe!
pub fn compile(b: *std.build.Builder, mode: std.builtin.Mode, target: std.zig.CrossTarget, wasm3_src_root: []const u8) *std.build.LibExeObjStep {

    const lib = b.addStaticLibrary("wasm3", null);
    lib.setBuildMode(mode);
    lib.setTarget(target);
    lib.linkLibC();
    lib.disable_sanitize_c = true;

    lib.defineCMacro("d_m3HasWASI");
    
    const src_dir = std.fs.path.join(b.allocator, &[_][]const u8{wasm3_src_root, "source"}) catch unreachable;

    var src_dir_handle = std.fs.cwd().openDir(src_dir, .{.iterate = true}) catch unreachable;
    defer src_dir_handle.close();

    lib.c_std = .C99;

    const cflags = [_][]const u8 {
        "-Wall", "-Wextra", "-Wparentheses", "-Wundef", "-Wpointer-arith", "-Wstrict-aliasing=2",
        "-Werror=implicit-function-declaration",
        "-Wno-unused-function", "-Wno-unused-variable", "-Wno-unused-parameter", "-Wno-missing-field-initializers"
    };

    var iter = src_dir_handle.iterate();
    while(iter.next() catch unreachable) |ent| {
        if(ent.kind == .File) {
            if(std.ascii.endsWithIgnoreCase(ent.name, ".c")) {
                lib.addCSourceFile(std.fs.path.join(b.allocator, &[_][]const u8{src_dir, ent.name}) catch unreachable, &cflags);
            }
        }
    }

    lib.addIncludeDir(src_dir);

    lib.addCSourceFile(std.fs.path.join(b.allocator, &[_][]const u8{
        std.fs.path.dirname(@src().file).?,
        "src", "wasm3_extra.c"
    }) catch unreachable, &cflags);


    return lib;
}

/// Compiles Wasm3 and links it into the provided exe.
/// If you use this API, you do not need to also use the compile() function.
pub fn addTo(exe: *std.build.LibExeObjStep, wasm3_src_root: []const u8) void {

    var lib = compile(exe.builder, exe.build_mode, exe.target, wasm3_src_root);
    exe.linkLibC();
    exe.linkLibrary(lib);
}