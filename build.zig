const std = @import("std");
const Builder = std.build.Builder;

pub const pkgs = @import("deps.zig").pkgs;
const self_plugin = @import("gyro_plugin.zig");

pub fn build(b: *Builder) void {

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("example", "example/test.zig");
    exe.setBuildMode(mode);
    exe.install();

    const wasm_build = b.addExecutable("wasm_example", "example/wasm_src.zig");
    wasm_build.target = std.zig.CrossTarget {
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    };
    wasm_build.out_filename = "wasm_example.wasm";

    self_plugin.addTo(exe);
    exe.addPackagePath("wasm3", "src/main.zig");

    exe.install();
    wasm_build.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addArtifactArg(wasm_build);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
