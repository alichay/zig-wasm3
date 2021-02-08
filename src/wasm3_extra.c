// Defines a public API for some of Wasm3's internals that are sort of important

// ReleaseFast has LTO now, so this should just optimize away...
// Hopefully!

#include <m3_env.h>
#include <m3_exec_defs.h>

void *wasm3_addon_get_runtime_stack(M3Runtime *runtime) {

    return runtime->stack;
}

u8 *wasm3_addon_get_runtime_mem_ptr(M3Runtime *runtime) {
    return m3MemData(runtime->memory.mallocated);
}

M3Runtime *wasm3_addon_get_fn_rt(M3Function *func) {
    return func->module->runtime;
}