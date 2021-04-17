const std = @import("std");
const root = @import("root");
const submod_build_plugin = @import("submod_build_plugin.zig");

fn getWasm3Src() []const u8 {
    const sep = std.fs.path.sep_str;
    
    const gyro_dir = comptime get_gyro: {
        const parent_dir = std.fs.path.dirname(@src().file).?;
        const maybe_clone_hash_dir = std.fs.path.dirname(parent_dir);
        const maybe_gyro_dir = if(maybe_clone_hash_dir) |d| std.fs.path.dirname(d) else null;

        if(std.ascii.eqlIgnoreCase(std.fs.path.basename(parent_dir), "pkg") and maybe_gyro_dir != null and
            std.ascii.eqlIgnoreCase(std.fs.path.basename(maybe_gyro_dir.?), ".gyro")) {
            break :get_gyro maybe_gyro_dir.?;
        } else {
            break :get_gyro std.fs.path.dirname(@src().file).? ++ sep ++ ".gyro";
        }
    };
    comptime {

        const gyro_lock = @embedFile("gyro.lock");
        var iter = std.mem.split(gyro_lock, "\n");
        while(iter.next()) |_line| {
            var line = std.mem.trim(u8, _line, &std.ascii.spaces);
            if(std.ascii.startsWithIgnoreCase(line, "github wasm3 wasm3")) {
                const commit = std.mem.trim(u8, line[std.mem.lastIndexOf(u8, line, " ").?..], &std.ascii.spaces);
                return gyro_dir ++ sep ++ "wasm3-wasm3-" ++ commit ++ sep ++ "pkg";
            }
        }
    }
    std.log.warn(
        "Searching for wasm3-wasm3-* in directory {s}\n" ++
        "If you didn't just update the version of wasm3 that we build with, something has gone very wrong!\n" ++
        "If you *did* update wasm3, however, this is fine and to be expected because gyro wants to successfully\nbuild before committing to gyro.lock.\n" ++
        "", .{gyro_dir}
    );
    
    {
        var gyro_dir_h = std.fs.cwd().openDir(gyro_dir, .{.iterate = true}) catch std.debug.panic("Failed to open .gyro directory, we thought it was at {s}\n", .{gyro_dir});
        defer gyro_dir_h.close();

        var dir_count: i32 = 0;
        var full_path: ?[]const u8 = null;

        var gyro_dir_iterator = gyro_dir_h.iterate();
        while(gyro_dir_iterator.next() catch unreachable) |ent| {
            if(ent.kind == .Directory and std.mem.startsWith(u8, ent.name, "wasm3-wasm3-")) {
                if(dir_count != 0) {
                    std.debug.warn("Can't determine which version of wasm3 to use.\n", .{});
                    std.debug.warn("gryo.lock is empty and there are multiple versions of wasm3 in .gyro\n", .{});
                    std.debug.panic("Please remove the all but the latest version of wasm3 from .gyro to continue.", .{});
                }
                dir_count += 1;
                full_path = std.fs.path.join(std.heap.page_allocator, &[_][]const u8{gyro_dir, ent.name}) catch unreachable;
            }
        }
        if(full_path) |fp| return fp;
    }
    std.debug.panic("Failed to determine location of wasm3. We looked in what we believed to be the .gyro directory:\n\t{s}\n", .{gyro_dir});
}

fn repoDir(b: *std.build.Builder) []const u8 {
    return std.fs.path.resolve(b.allocator, &[_][]const u8{b.build_root, getWasm3Src()}) catch unreachable;
}

/// Queues a build job for the C code of Wasm3.
/// This builds a static library that depends on libc, so make sure to link that into your exe!
pub fn compile(b: *std.build.Builder, mode: std.builtin.Mode, target: std.zig.CrossTarget) *std.build.LibExeObjStep {
    return submod_build_plugin.compile(b, mode, target, repoDir(b));
}

/// Compiles Wasm3 and links it into the provided exe.
/// If you use this API, you do not need to also use the compile() function.
pub fn addTo(exe: *std.build.LibExeObjStep) void {
    submod_build_plugin.addTo(exe, repoDir(exe.builder));
}

var file_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;

pub fn pkg(name: ?[]const u8) std.build.Pkg {
    var fba = std.heap.FixedBufferAllocator.init(&file_buf);
    return .{
        .name = name orelse "wasm3",
        .path = std.fs.path.join(&fba.allocator, &[_][]const u8{std.fs.path.dirname(@src().file).?, "src", "main.zig"}) catch unreachable,
    };
}