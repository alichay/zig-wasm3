const std = @import("std");
const root = @import("root");
const submod_build_plugin = @import("submod_build_plugin.zig");

fn repoDir(b: *std.build.Builder, comptime pkgs: anytype) []const u8 {
    return std.fs.path.resolve(b.allocator, &[_][]const u8{b.build_root, getWasm3Src(pkgs), ".."}) catch unreachable;
}

fn getWasm3Src(comptime p: anytype) []const u8 {
    if(@hasDecl(p, "wasm3_csrc")) {
        return p.wasm3_csrc.path;
    } else {
        @compileError("pkgs argument doesn't contain the wasm3 source repository. Are you sure you passed @import(\"gyro\").pkgs?");
    }
}

/// Queues a build job for the C code of Wasm3.
/// This builds a static library that depends on libc, so make sure to link that into your exe!
pub fn compile(b: *std.build.Builder, mode: std.builtin.Mode, target: std.zig.CrossTarget, comptime pkgs: anytype) *std.build.LibExeObjStep {
    return submod_build_plugin.compile(b, mode, target, repoDir(b, pkgs));
}

/// Compiles Wasm3 and links it into the provided exe.
/// If you use this API, you do not need to also use the compile() function.
pub fn addTo(exe: *std.build.LibExeObjStep, comptime pkgs: anytype) void {
    submod_build_plugin.addTo(exe, repoDir(exe.builder, pkgs));
}

var file_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;

pub fn pkg(name: ?[]const u8) std.build.Pkg {
    var fba = std.heap.FixedBufferAllocator.init(&file_buf);
    return .{
        .name = name orelse "wasm3",
        .path = std.fs.path.join(&fba.allocator, &[_][]const u8{std.fs.path.dirname(@src().file).?, "src", "main.zig"}) catch unreachable,
    };
}