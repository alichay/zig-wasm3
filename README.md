# zig-wasm3

Zig bindings (and build system integration) for [Wasm3](https://github.com/wasm3/wasm3)

#### TODO: Figure out how to package this better.
Right now, we only support Gyro, and that support is hacked together with a normal dependency *and* a build dependency. I don't know if I'm using Gyro wrong, or if it just doesn't support complex mixed-c-zig projects yet. Either way, something to look out for!

## Usage

zig-wasm3 is primarily targeted for the Gyro package manager, but you can also use it with git submodules.
