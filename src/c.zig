usingnamespace @import("std").c.builtins;

pub const M3Result = [*c]const u8;
pub const IM3Environment = ?*opaque {};
pub const IM3Runtime = ?*opaque {};
pub const IM3Module = ?*opaque {};
pub const IM3Function = ?*opaque {};
pub const IM3Global = ?*opaque {};

pub const M3ErrorInfo = extern struct {
    result: M3Result,
    runtime: IM3Runtime,
    module: IM3Module,
    function: IM3Function,
    file: [*c]const u8,
    line: u32,
    message: [*c]const u8,
};

pub const M3BacktraceFrame = extern struct {
    moduleOffset: u32,
    function: IM3Function,
    next: ?*M3BacktraceFrame,
};

pub const M3BacktraceInfo = extern struct {
    frames: ?*M3BacktraceFrame,
    lastFrame: ?*M3BacktraceFrame,

    pub fn lastFrameTruncated(self: *M3BacktraceInfo) callconv(.Inline) bool {
        const std = @import("std");
        const last_frame = @ptrToInt(usize, self.lastFrame);

        // M3_BACKTRACE_TRUNCATED is defined as (void*)(SIZE_MAX)
        return last_frame == std.math.maxInt(usize);
    }
};

pub const M3ValueType = extern enum(c_int) {
    None = 0,
    Int32 = 1,
    Int64 = 2,
    Float32 = 3,
    Float64 = 4,
    Unknown = 5,
};

pub const M3TaggedValue = extern struct {
    kind: M3ValueType,
    value: extern union {
        // The wasm3 API has the integers as unsigned,
        // but the spec and naming convention seems to imply
        // that they're actually signed. I can't find an example
        // of wasm working with global integers, so we're just winging it
        // and if it breaks something we'll just have to fix it unfortunately.
        int32: i32,
        int64: i64,
        float32: f32,
        float64: f64,
    }
};

pub const M3ImportInfo = extern struct {
    moduleUtf8: [*c]const u8,
    fieldUtf8: [*c]const u8,
};

pub const M3ImportContext = extern struct {
    userdata: ?*c_void,
    function: IM3Function,
};

pub extern var m3Err_none: M3Result;

// general errors
pub extern var m3Err_mallocFailed: M3Result;

// parse errors
pub extern var m3Err_incompatibleWasmVersion: M3Result;
pub extern var m3Err_wasmMalformed: M3Result;
pub extern var m3Err_misorderedWasmSection: M3Result;
pub extern var m3Err_wasmUnderrun: M3Result;
pub extern var m3Err_wasmOverrun: M3Result;
pub extern var m3Err_wasmMissingInitExpr: M3Result;
pub extern var m3Err_lebOverflow: M3Result;
pub extern var m3Err_missingUTF8: M3Result;
pub extern var m3Err_wasmSectionUnderrun: M3Result;
pub extern var m3Err_wasmSectionOverrun: M3Result;
pub extern var m3Err_invalidTypeId: M3Result;
pub extern var m3Err_tooManyMemorySections: M3Result;
pub extern var m3Err_tooManyArgsRets: M3Result;

// link errors
pub extern var m3Err_moduleAlreadyLinked: M3Result;
pub extern var m3Err_functionLookupFailed: M3Result;
pub extern var m3Err_functionImportMissing: M3Result;

pub extern var m3Err_malformedFunctionSignature: M3Result;

// compilation errors
pub extern var m3Err_noCompiler: M3Result;
pub extern var m3Err_unknownOpcode: M3Result;
pub extern var m3Err_restictedOpcode: M3Result;
pub extern var m3Err_functionStackOverflow: M3Result;
pub extern var m3Err_functionStackUnderrun: M3Result;
pub extern var m3Err_mallocFailedCodePage: M3Result;
pub extern var m3Err_settingImmutableGlobal: M3Result;
pub extern var m3Err_typeMismatch: M3Result;
pub extern var m3Err_typeCountMismatch: M3Result;

// runtime errors
pub extern var m3Err_missingCompiledCode: M3Result;
pub extern var m3Err_wasmMemoryOverflow: M3Result;
pub extern var m3Err_globalMemoryNotAllocated: M3Result;
pub extern var m3Err_globaIndexOutOfBounds: M3Result;
pub extern var m3Err_argumentCountMismatch: M3Result;
pub extern var m3Err_argumentTypeMismatch: M3Result;
pub extern var m3Err_globalLookupFailed: M3Result;
pub extern var m3Err_globalTypeMismatch: M3Result;
pub extern var m3Err_globalNotMutable: M3Result;

// traps
pub extern var m3Err_trapOutOfBoundsMemoryAccess: M3Result;
pub extern var m3Err_trapDivisionByZero: M3Result;
pub extern var m3Err_trapIntegerOverflow: M3Result;
pub extern var m3Err_trapIntegerConversion: M3Result;
pub extern var m3Err_trapIndirectCallTypeMismatch: M3Result;
pub extern var m3Err_trapTableIndexOutOfRange: M3Result;
pub extern var m3Err_trapTableElementIsNull: M3Result;
pub extern var m3Err_trapExit: M3Result;
pub extern var m3Err_trapAbort: M3Result;
pub extern var m3Err_trapUnreachable: M3Result;
pub extern var m3Err_trapStackOverflow: M3Result;

pub extern fn m3_NewEnvironment() IM3Environment;
pub extern fn m3_FreeEnvironment(i_environment: IM3Environment) void;
pub extern fn m3_NewRuntime(io_environment: IM3Environment, i_stackSizeInBytes: u32, i_userdata: ?*c_void) IM3Runtime;
pub extern fn m3_FreeRuntime(i_runtime: IM3Runtime) void;
pub extern fn m3_GetMemory(i_runtime: IM3Runtime, o_memorySizeInBytes: [*c]u32, i_memoryIndex: u32) [*c]u8;
pub extern fn m3_GetUserData(i_runtime: IM3Runtime) ?*c_void;
pub extern fn m3_ParseModule(i_environment: IM3Environment, o_module: *IM3Module, i_wasmBytes: [*]const u8, i_numWasmBytes: u32) M3Result;
pub extern fn m3_FreeModule(i_module: IM3Module) void;
pub extern fn m3_LoadModule(io_runtime: IM3Runtime, io_module: IM3Module) M3Result;
pub extern fn m3_RunStart(i_module: IM3Module) M3Result;
/// Arguments and return values are passed in and out through the stack pointer _sp.
/// Placeholder return value slots are first and arguments after. So, the first argument is at _sp [numReturns]
/// Return values should be written into _sp [0] to _sp [num_returns - 1]
pub const M3RawCall = ?fn (IM3Runtime, ctx: *M3ImportContext, [*c]u64, ?*c_void) callconv(.C) ?*const c_void;
pub extern fn m3_LinkRawFunction(io_module: IM3Module, i_moduleName: [*:0]const u8, i_functionName: [*:0]const u8, i_signature: [*c]const u8, i_function: M3RawCall) M3Result;
pub extern fn m3_LinkRawFunctionEx(io_module: IM3Module, i_moduleName: [*:0]const u8, i_functionName: [*:0]const u8, i_signature: [*c]const u8, i_function: M3RawCall, i_userdata: ?*const c_void) M3Result;
/// Returns "<unknown>" on failure, but this behavior isn't described in the API so could be subject to change.
pub extern fn m3_GetModuleName(i_module: IM3Module) [*:0]u8;
pub extern fn m3_GetModuleRuntime(i_module: IM3Module) IM3Runtime;
pub extern fn m3_FindGlobal(io_module: IM3Module, i_globalName: [*:0]const u8) IM3Global;
pub extern fn m3_GetGlobal(i_global: IM3Global, i_value: *M3TaggedValue) M3Result;
pub extern fn m3_SetGlobal(i_global: IM3Global, i_value: *const M3TaggedValue) M3Result;
pub extern fn m3_GetGlobalType(i_global: IM3Global) M3ValueType;
pub extern fn m3_Yield() M3Result;
pub extern fn m3_FindFunction(o_function: [*c]IM3Function, i_runtime: IM3Runtime, i_functionName: [*c]const u8) M3Result;
pub extern fn m3_GetArgCount(i_function: IM3Function) u32;
pub extern fn m3_GetRetCount(i_function: IM3Function) u32;
pub extern fn m3_GetArgType(i_function: IM3Function, index: u32) M3ValueType;
pub extern fn m3_GetRetType(i_function: IM3Function, index: u32) M3ValueType;
pub extern fn m3_CallV(i_function: IM3Function, ...) M3Result;
pub extern fn m3_Call(i_function: IM3Function, i_argc: u32, i_argptrs: [*c]?*const c_void) M3Result;
pub extern fn m3_CallArgV(i_function: IM3Function, i_argc: u32, i_argv: [*c][*c]const u8) M3Result;
pub extern fn m3_GetResults(i_function: IM3Function, i_retc: u32, ret_ptrs: [*c]?*c_void) M3Result;
pub extern fn m3_GetErrorInfo(i_runtime: IM3Runtime, info: [*c]M3ErrorInfo) void;
pub extern fn m3_ResetErrorInfo(i_runtime: IM3Runtime) void;
/// Returns "<unnamed>" on failure, but this behavior isn't described in the API so could be subject to change.
pub extern fn m3_GetFunctionName(i_function: IM3Function) [*:0]const u8;
pub extern fn m3_GetFunctionModule(i_function: IM3Function) IM3Module;
pub extern fn m3_PrintRuntimeInfo(i_runtime: IM3Runtime) void;
pub extern fn m3_PrintM3Info() void;
pub extern fn m3_PrintProfilerInfo() void;
pub extern fn m3_GetBacktrace(i_runtime: IM3Runtime) ?*M3BacktraceInfo;

pub extern fn m3_LinkWASI(io_module: IM3Module) M3Result;
