# zig-wasm3

Zig bindings (and build system integration) for [Wasm3](https://github.com/wasm3/wasm3)

#### TODO: Figure out how to package this better.
Right now, we only support Gyro, and that support is hacked together with a normal dependency *and* a build dependency. I don't know if I'm using Gyro wrong, or if it just doesn't support complex mixed-c-zig projects yet. Either way, something to look out for!

## Usage

Building this project requires master-branch zig for now.
You can obtain a master branch build of zig from https://ziglang.org/download

zig-wasm3 is primarily targeted for the Gyro package manager, but you can also use it with git submodules.

* [Using with Gyro](#using-with-gyro)
* [Using with Git Submodules](#using-with-git-submodules)

Both methods are pretty simple, and both include a build system to compile wasm3 from source.
Gyro, however, builds a known-good version of wasm3 that has been tested with these bindings, while submodules will build whatever version you clone, so use caution!

#### Using With Gyro
To use with Gyro, add the following to your `gyro.zzz` file
```
build_deps:
  wasm3-build:
    src:
      github:
        user: alichay
        repo: zig-wasm3
        ref: main
    root: gyro_plugin.zig
```
You should be able to do the same on the command line with
```
$ gyro add -b -s github 'alichay/zig-wasm3' -r 'gyro_plugin.zig' -a 'wasm3-build'
```
but gyro's CLI behaved oddly when I tried to do this.

Then, import the wasm3 builder into your `build.zig` file, and add the library to your project!

`build.zig`
```rust
pub const wasm3_build = @import("wasm3-build");

pub fn build(b: *std.build.Builder) void {
    // ...
    wasm3_build.addTo(exe);
    // Replace null with a string to override package name.
    // By default, it is "wasm3"
    exe.addPackage(wasm3_build.pkg(null));
    // ...
}
```

From there, you can just `@import("wasm3")` in your application!

#### Using with Git Submodules

Git submodules are the devil. Additionally, unlike Gyro, it's a little bit more difficult to version control submodules, as these bindings are written to specific versions of wasm3 that aren't always up-to-date (this is a hobby project that I don't use much anymore, so updates lag behind quite a bit).
If you can, you should absolutely use gyro to ensure that you have a compatible version of the wasm3 library to use with these bindings. If that's not possible, however, submodules are better than nothing.

To use wasm3 with submodules, you need to add two submodules to your project.
In this example, I'm going to put them in `/libs`, but that's completely up to you.

```bash
git submodule add 'https://github.com/alichay/zig-wasm3' 'libs/zig-wasm3'
git submodule add 'https://github.com/wasm3/wasm3' 'libs/wasm3'
```

Then, in `build.zig`, reference the zig-wasm3 build script, and pass it the path to the wasm3 repository.

```rust
pub const wasm3_build = @import("libs/zig-wasm3/submod_build_plugin.zig");

pub fn build(b: *std.build.Builder) void {
    // ...
    wasm3_build.addTo(exe, "libs/wasm3");
    // Replace null with a string to override package name.
    // By default, it is "wasm3"
    exe.addPackage(wasm3_build.pkg(null));
    // ...
}
```

From there, you can just `@import("wasm3")` in your application!