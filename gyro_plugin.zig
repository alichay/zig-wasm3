const std = @import("std");
const root = @import("root");
const pkgs = if(@hasDecl(root, "pkgs")) root.pkgs else @import("gyro").pkgs;
const submod_build_plugin = @import("submod_build_plugin.zig");

fn repoDir(b: *std.build.Builder) []const u8 {
    return std.fs.path.resolve(b.allocator, &[_][]const u8{b.build_root, pkgs.wasm3_csrc.path, "..", ".."}) catch unreachable;
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