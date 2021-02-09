const std = @import("std");
const root = @import("root");
const submod_build_plugin = @import("submod_build_plugin.zig");

fn getWasm3Src() []const u8 {
    const sep = std.fs.path.sep_str;
    comptime {
        const gyro_dir = get_gyro: {
            const parent_dir = std.fs.path.dirname(std.fs.path.dirname(@src().file).?).?;
            const further_parent = std.fs.path.dirname(parent_dir);
            if(std.ascii.eqlIgnoreCase(std.fs.path.basename(parent_dir), "pkg") and further_parent != null and
               std.ascii.eqlIgnoreCase(std.fs.path.basename(further_parent.?), ".gyro")) {
                break :get_gyro further_parent.?;
            } else {
                break :get_gyro std.fs.path.dirname(@src().file).? ++ sep ++ ".gyro";
            }
        };

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
    @compileError("Failed to find wasm3 source repository!");
}

fn repoDir(b: *std.build.Builder) []const u8 {
    return std.fs.path.resolve(b.allocator, &[_][]const u8{b.build_root, comptime getWasm3Src()}) catch unreachable;
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