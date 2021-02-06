usingnamespace @import("std").c.builtins;

pub const M3Result = [*c]const u8;
pub const IM3Environment = ?*opaque {};
pub const IM3Runtime = ?*opaque {};
pub const IM3Module = ?*opaque {};
pub const IM3Function = ?*opaque {};

pub const M3ErrorInfo = extern struct {
    result: M3Result,
    runtime: IM3Runtime,
    module: IM3Module,
    function: IM3Function,
    file: [*c]const u8,
    line: u32,
    message: [*c]const u8,
};

pub const M3ValueType = extern enum(c_int) {
    none = 0,
    i32 = 1,
    i64 = 2,
    f32 = 3,
    f64 = 4,
    unknown = 5,
};
pub const M3ImportInfo = extern struct {
    moduleUtf8: [*c]const u8,
    fieldUtf8: [*c]const u8,
};

pub extern var m3Err_none: M3Result;
pub extern var m3Err_typeListOverflow: M3Result;
pub extern var m3Err_mallocFailed: M3Result;
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
pub extern var m3Err_moduleAlreadyLinked: M3Result;
pub extern var m3Err_functionLookupFailed: M3Result;
pub extern var m3Err_functionImportMissing: M3Result;
pub extern var m3Err_malformedFunctionSignature: M3Result;
pub extern var m3Err_noCompiler: M3Result;
pub extern var m3Err_unknownOpcode: M3Result;
pub extern var m3Err_functionStackOverflow: M3Result;
pub extern var m3Err_functionStackUnderrun: M3Result;
pub extern var m3Err_mallocFailedCodePage: M3Result;
pub extern var m3Err_settingImmutableGlobal: M3Result;
pub extern var m3Err_optimizerFailed: M3Result;
pub extern var m3Err_missingCompiledCode: M3Result;
pub extern var m3Err_wasmMemoryOverflow: M3Result;
pub extern var m3Err_globalMemoryNotAllocated: M3Result;
pub extern var m3Err_globaIndexOutOfBounds: M3Result;
pub extern var m3Err_argumentCountMismatch: M3Result;
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
pub extern fn m3_ParseModule(i_environment: IM3Environment, o_module: [*c]IM3Module, i_wasmBytes: [*c]const u8, i_numWasmBytes: u32) M3Result;
pub extern fn m3_FreeModule(i_module: IM3Module) void;
pub extern fn m3_LoadModule(io_runtime: IM3Runtime, io_module: IM3Module) M3Result;
pub const M3RawCall = ?fn (IM3Runtime, [*c]u64, ?*c_void, ?*c_void) callconv(.C) ?*const c_void;
pub extern fn m3_LinkRawFunction(io_module: IM3Module, i_moduleName: [*c]const u8, i_functionName: [*c]const u8, i_signature: [*c]const u8, i_function: M3RawCall) M3Result;
pub extern fn m3_LinkRawFunctionEx(io_module: IM3Module, i_moduleName: [*c]const u8, i_functionName: [*c]const u8, i_signature: [*c]const u8, i_function: M3RawCall, i_userdata: ?*const c_void) M3Result;
pub extern fn m3_Yield() M3Result;
pub extern fn m3_FindFunction(o_function: [*c]IM3Function, i_runtime: IM3Runtime, i_functionName: [*c]const u8) M3Result;
pub extern fn m3_GetArgCount(i_function: IM3Function) u32;
pub extern fn m3_GetRetCount(i_function: IM3Function) u32;
pub extern fn m3_GetArgType(i_function: IM3Function, index: u32) M3ValueType;
pub extern fn m3_GetRetType(i_function: IM3Function, index: u32) M3ValueType;
pub extern fn m3_CallVariadic(i_function: IM3Function, i_argc: u32, ...) M3Result;
pub extern fn m3_Call(i_function: IM3Function, i_argc: u32, i_argptrs: [*c]?*const c_void) M3Result;
pub extern fn m3_CallWithArgs(i_function: IM3Function, i_argc: u32, i_argv: [*c][*c]const u8) M3Result;
pub extern fn m3_GetErrorInfo(i_runtime: IM3Runtime, info: [*c]M3ErrorInfo) void;
pub extern fn m3_ResetErrorInfo(i_runtime: IM3Runtime) void;
pub extern fn m3_PrintRuntimeInfo(i_runtime: IM3Runtime) void;
pub extern fn m3_PrintM3Info() void;
pub extern fn m3_PrintProfilerInfo() void;

pub extern fn m3_LinkWASI(io_module: IM3Module) M3Result;