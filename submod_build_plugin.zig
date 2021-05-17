const std = @import("std");
const root = @import("root");

/// Queues a build job for the C code of Wasm3.
/// This builds a static library that depends on libc, so make sure to link that into your exe!
pub fn compile(b: *std.build.Builder, mode: std.builtin.Mode, target: std.zig.CrossTarget, wasm3_root: []const u8) *std.build.LibExeObjStep {

    const lib = b.addStaticLibrary("wasm3", null);
    lib.setBuildMode(mode);
    lib.setTarget(target);
    lib.linkLibC();
    lib.disable_sanitize_c = true;

    lib.defineCMacro("d_m3HasWASI");
    
    const src_dir = std.fs.path.join(b.allocator, &.{wasm3_root, "source"}) catch unreachable;

    var src_dir_handle = std.fs.cwd().openDir(src_dir, .{.iterate = true}) catch unreachable;
    defer src_dir_handle.close();

    lib.c_std = .C99;

    const cflags = [_][]const u8 {
        "-Wall", "-Wextra", "-Wparentheses", "-Wundef", "-Wpointer-arith", "-Wstrict-aliasing=2",
        "-Werror=implicit-function-declaration",
        "-Wno-unused-function", "-Wno-unused-variable", "-Wno-unused-parameter", "-Wno-missing-field-initializers",
    };
    const cflags_with_windows_posix_aliases = cflags ++ [_][]const u8 {
        "-Dlseek(fd,off,whence)=_lseek(fd,off,whence)",
        "-Dfileno(stream)=_fileno(stream)",
        "-Dsetmode(fd,mode)=_setmode(fd,mode)",
    };

    var core_src_file: ?[]const u8 = undefined;

    var iter = src_dir_handle.iterate();
    while(iter.next() catch unreachable) |ent| {
        if(ent.kind == .File) {
            if(std.ascii.endsWithIgnoreCase(ent.name, ".c")) {
                const path = std.fs.path.join(b.allocator, &[_][]const u8{src_dir, ent.name}) catch unreachable;
                if(std.ascii.eqlIgnoreCase(ent.name, "m3_core.c")) {
                    core_src_file = path;
                    continue;
                }
                if(
                    target.isWindows() and
                    std.ascii.eqlIgnoreCase(ent.name, "m3_api_wasi.c")
                ) {
                    lib.addCSourceFile(path, &cflags_with_windows_posix_aliases);
                } else {
                    lib.addCSourceFile(path, &cflags);
                }
            }
        }
    }

    std.debug.assert(core_src_file != null);

    { // Patch source files.

        // wasm3 has a built-in limit for what it thinks should be the maximum sane length for a utf-8 string
        // It's 2000 characters, which seems reasonable enough.
        //
        // Here's the thing - C++ is not reasonable.
        // libc++'s rtti symbols exceed four-freakin'-thousand characters sometimes.
        // In order to support compiled C++ programs, we patch this value.
        //
        // It's kind of ugly, but it works!

        var build_root_handle = std.fs.cwd().openDir(wasm3_root, .{}) catch unreachable;
        defer build_root_handle.close();

        std.fs.cwd().copyFile(core_src_file.?, build_root_handle, "m3_core.c", .{}) catch unreachable;
        lib.addCSourceFile(std.fs.path.join(b.allocator, &[_][]const u8{wasm3_root, "m3_core.c"}) catch unreachable, &cflags);

        build_root_handle.writeFile("m3_core.h", "#include <m3_core.h>\n" ++
                                                 "#undef d_m3MaxSaneUtf8Length\n" ++
                                                 "#define d_m3MaxSaneUtf8Length 10000\n") catch unreachable;

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
pub fn addTo(exe: *std.build.LibExeObjStep, wasm3_root: []const u8) void {

    var lib = compile(exe.builder, exe.build_mode, exe.target, wasm3_root);
    exe.linkLibC();
    exe.linkLibrary(lib);
}

var file_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;

pub fn pkg(name: ?[]const u8) std.build.Pkg {
    var fba = std.heap.FixedBufferAllocator.init(&file_buf);
    return .{
        .name = name orelse "wasm3",
        .path = std.fs.path.join(&fba.allocator, &[_][]const u8{std.fs.path.dirname(@src().file).?, "src", "main.zig"}) catch unreachable,
    };
}