const std = @import("std");
const root = @import("root");
const submod_build_plugin = @import("submod_build_plugin.zig");
const zzz = @import("zzz");

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
    const gyro_zzz_src = @embedFile("gyro.zzz");
    const path = [_][]const u8{"deps", "wasm3_csrc", "src", "github", "ref"};

    var tree = zzz.ZTree(1, 100){};
    var config_node = tree.appendText(gyro_zzz_src) catch unreachable;
    for(path) |key| {
        config_node = config_node.findNth(0, .{.String = key}) orelse unreachable;
    }
    return std.mem.join(std.heap.page_allocator, "", &.{gyro_dir, sep, "wasm3-wasm3-", config_node.child.?.value.String, sep, "pkg"}) catch unreachable;
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

pub const pkg = submod_build_plugin.pkg;