const std = @import("std");
const testing = std.testing;

const c = @import("c.zig");

/// Map an M3Result to the matching Error value.
fn mapError(result: c.M3Result) Error!void {
    @setEvalBranchQuota(50000);
    const match_list = comptime get_results: {
        const Declaration = std.builtin.TypeInfo.Declaration;
        var result_values: []const [2][]const u8 = &[0][2][]const u8{};
        for(std.meta.declarations(c)) |decl| {
            const d: Declaration = decl;
            if(std.mem.startsWith(u8, d.name, "m3Err_")) {
                if(!std.mem.eql(u8, d.name, "m3Err_none")) {
                    var error_name = d.name[("m3Err_").len..];

                    error_name = get: for(std.meta.fieldNames(Error)) |f| {
                        if(std.ascii.eqlIgnoreCase(error_name, f)) {
                            break :get f;
                        }
                    } else {
                        @compileError("Failed to find matching error for code " ++ d.name);
                    };

                    result_values = result_values ++ [1][2][]const u8{
                        [2][]const u8{d.name, error_name}
                    };
                }
            }
        }
        break :get_results result_values;
    };

    if(result == c.m3Err_none) return;
    inline for(match_list) |pair| {
        if(result == @field(c, pair[0])) return @field(Error, pair[1]);
    }
    unreachable;
}

const Error = error {
    TypeListOverflow,
    MallocFailed,
    IncompatibleWasmVersion,
    WasmMalformed,
    MisorderedWasmSection,
    WasmUnderrun,
    WasmOverrun,
    WasmMissingInitExpr,
    LebOverflow,
    MissingUtf8,
    WasmSectionUnderrun,
    WasmSectionOverrun,
    InvalidTypeId,
    TooManyMemorySections,
    ModuleAlreadyLinked,
    FunctionLookupFailed,
    FunctionImportMissing,
    MalformedFunctionSignature,
    NoCompiler,
    UnknownOpcode,
    FunctionStackOverflow,
    FunctionStackUnderrun,
    MallocFailedCodePage,
    SettingImmutableGlobal,
    OptimizerFailed,
    MissingCompiledCode,
    WasmMemoryOverflow,
    GlobalMemoryNotAllocated,
    GlobaIndexOutOfBounds,
    ArgumentCountMismatch,
    TrapOutOfBoundsMemoryAccess,
    TrapDivisionByZero,
    TrapIntegerOverflow,
    TrapIntegerConversion,
    TrapIndirectCallTypeMismatch,
    TrapTableIndexOutOfRange,
    TrapTableElementIsNull,
    TrapExit,
    TrapAbort,
    TrapUnreachable,
    TrapStackOverflow,
};

pub const Runtime = struct {
    impl: c.IM3Runtime,

    pub inline fn deinit(this: Runtime) void {
        c.m3_FreeRuntime(this.impl);
    }
    pub inline fn getMemory(this: Runtime, memory_index: u32) ?[]u8 {
        var size: u32 = 0;
        var mem = c.m3_GetMemory(this.impl, &size, memory_index);
        if(mem) |valid| {
            return valid[0..@intCast(usize, size)];
        }
        return null;
    }
    pub inline fn getUserData(this: Runtime) ?*c_void {
        return c.m3_GetUserData(this.impl);
    }

    pub inline fn loadModule(this: Runtime, module: Module) !void {
        try mapError(c.m3_LoadModule(this.impl, module.impl));
    }

    pub inline fn findFunction(this: Runtime, function_name: [:0]const u8) !Function {
        var func = Function{.impl = undefined};
        try mapError(c.m3_FindFunction(&func.impl, this.impl, function_name.ptr));
        return func;
    }
    pub inline fn printRuntimeInfo(this: Runtime) void {
        c.m3_PrintRuntimeInfo(this.impl);
    }
    pub const ErrorInfo = c.M3ErrorInfo;
    pub inline fn getErrorInfo(this: Runtime) ErrorInfo {
        var info: ErrorInfo = undefined;
        c.m3_GetErrorInfo(this.impl, &info);
        return info;
    }
    inline fn span(strz: ?[*:0]const u8) []const u8{
        if(strz) |s| return std.mem.span(s);
        return "nullptr";
    }
    pub inline fn printError(this: Runtime) void {
        var info = this.getErrorInfo();
        this.resetErrorInfo();
        std.log.err("Wasm3 error: {s} @ {s}:{d}\n", .{span(info.message), span(info.file), info.line});
    }
    pub inline fn resetErrorInfo(this: Runtime) void {
        c.m3_ResetErrorInfo(this.impl);
    }
};

pub const Function = struct {
    impl: c.IM3Function,

    pub inline fn getArgCount(this: Function) u32 {
        return c.m3_GetArgCount(this.impl);
    }
    pub inline fn getRetCount(this: Function) u32 {
        return c.m3_GetRetCount(this.impl);
    }
    pub inline fn getArgType(this: Function, idx: u32) c.M3ValueType {
        return c.m3_GetArgType(this.impl, idx);
    }
    pub inline fn getRetType(this: Function, idx: u32) c.M3ValueType {
        return c.m3_GetRetType(this.impl, idx);
    }
    /// Call a function, using a provided tuple for arguments.
    /// TYPES ARE NOT VALIDATED. Be careful
    /// TDOO: Test this! Zig has weird symbol export issues with wasm right now,
    ///       so I can't verify that arguments or return values are properly passes!
    pub inline fn call(this: Function, comptime RetType: type, args: anytype) !RetType {
        const ArgsType = @TypeOf(args);
        if (@typeInfo(ArgsType) != .Struct) {
            @compileError("Expected tuple or struct argument, found " ++ @typeName(ArgsType));
        }
        const fields_info = std.meta.fields(ArgsType);

        const count = fields_info.len;
        var arg_arr: [count]?*const c_void = undefined;
        inline for(args) |*a, i| {
            const arg_is_ptr = switch(@typeInfo(RetType)) {
                .Struct => @hasDecl(RetType, "_is_wasm3_local_ptr"),
                else => false,
            };
            if(arg_is_ptr) {
                arg_arr[i] = @intToPtr(?*const c_void,
                    @truncate(u32, @ptrToInt(a.host_ptr) - @ptrToInt(a.local_heap))
                );
            } else {
                arg_arr[i] = @ptrCast(?*const c_void, a);
            }
        }
        // TODO: Perhaps we should use CallWithArgs instead of Call?
        //       Call passes pointers to params, while CallWithArgs
        //       creates a packed buffer of actual data instead.
        //       This is kind of a nitpick though
        try mapError(c.m3_Call(this.impl, @intCast(u32, count), if(count == 0) null else &arg_arr));
        

        const is_ptr = switch(@typeInfo(RetType)) {
            .Struct => @hasDecl(RetType, "_is_wasm3_local_ptr"),
            else => false,
        };

        if(RetType == void) return;

        const Extensions = struct {
            pub extern fn wasm3_addon_get_runtime_stack(rt: c.IM3Runtime) [*c]u8;
            pub extern fn wasm3_addon_get_runtime_mem_ptr(rt: c.IM3Runtime) [*c]u8;
            pub extern fn wasm3_addon_get_fn_rt(func: c.IM3Function) c.IM3Runtime;
        };

        const runtime_ptr = Extensions.wasm3_addon_get_fn_rt(this.impl);
        const stack_ptr = Extensions.wasm3_addon_get_runtime_stack(runtime_ptr);

        if(is_ptr) {
            const mem_ptr = Extensions.wasm3_addon_get_runtime_mem_ptr(runtime_ptr);
            return RetType {
                .local_heap = mem_ptr,
                .host_ptr = @intToPtr(*RetType.Base, @ptrToInt(mem_ptr) + @intCast(usize, @intToPtr(*u32, stack_ptr).*)),
            };
        }
        switch(RetType) {
            i8, i16, i32, i64,
            u8, u16, u32, u64,
            f32, f64 => {
                return @ptrCast(RetType, @ptrCast(*RetType, stack_ptr)).*;
            }
        }
        @compileError("Invalid WebAssembly return type " ++ @typeName(RetType) ++ "!");
    }
};

pub fn NativePtr(comptime T: type) type {
    comptime {
        switch(T) {
            i8, i16, i32, i64 => {},
            u8, u16, u32, u64 => {},
            else => @compileError("Invalid type for a NativePtr. Must be an integer!"),
        }
    }
    return struct {
        const _is_wasm3_local_ptr = true;
        pub const Base = T;
        local_heap: usize,
        host_ptr: *T,
        const Self = @This();

        pub inline fn localPtr(this: Self) u32 {
            return @intCast(u32, @ptrToInt(this.host_ptr) - this.local_heap);
        }
        pub inline fn write(this: Self, val: T) void {
            std.mem.writeIntLittle(T, std.mem.asBytes(this.host_ptr), val);
        }
        pub inline fn read(this: Self) T {
            return std.mem.readIntLittle(T, std.mem.asBytes(this.host_ptr));
        }
        inline fn offsetBy(this: Self, offset: i64) *T {
            return @intToPtr(*T, get_ptr: {
                if(offset > 0) {
                    break :get_ptr @ptrToInt(this.host_ptr) + @intCast(usize, offset);
                } else {
                    break :get_ptr @ptrToInt(this.host_ptr) - @intCast(usize, -offset);
                }
            });
        }
        /// Offset is in bytes, NOT SAFETY CHECKED.
        pub inline fn writeOffset(this: Self, offset: i64, val: T) void {
            std.mem.writeIntLittle(T, std.mem.asBytes(this.offsetBy(offset)), val);
        }
        /// Offset is in bytes, NOT SAFETY CHECKED.
        pub inline fn readOffset(this: Self, offset: i64) T {
            std.mem.readIntLittle(T, std.mem.asBytes(this.offsetBy(offset)));
        }
        pub usingnamespace if(T == u8) struct {
            /// NOT SAFETY CHECKED.
            pub inline fn slice(this: Self, len: u32) []T {
                return @ptrCast([*]u8, this.host_ptr)[0..@intCast(usize, len)];
            }
        } else struct {};
    };
}

pub const Module = struct {

    impl: c.IM3Module,

    pub fn deinit(this: Module) void {
        c.m3_FreeModule(this.impl);
    }

    fn mapTypeToChar(comptime T: type) u8 {
        switch(T) {
            void => return 'v',
            u32, i32 =>  return 'i',
            u64, i64 =>  return 'I',
            f32 =>  return 'f',
            f64 =>  return 'F',
            else => {},
        }
        if(@hasDecl(T, "_is_wasm3_local_ptr")) {
            return '*';
        }
        switch(@typeInfo(T)) {
            .Pointer => |ptrti| {
                if(ptrti.size == .One) {
                    @compileError("Please use a wasm3.NativePtr instead of raw pointers!");
                }
            }
        }
        @compileError("Invalid type " ++ @typeName(T) ++ " for WASM interop!");
    }

    pub fn linkWasi(this: Module) !void {
        return mapError(c.m3_LinkWASI(this.impl));
    }

    /// Links all functions in a struct to the module.
    /// library_name: the name of the library this function should belong to.
    /// library: a struct containing functions that should be added to the module.
    ///          See linkRawFunction(...) for information about valid function signatures.
    /// userdata: A single-item pointer passed to the function as the first argument when called.
    ///           Not accessible from within wasm, handled by the interpreter.
    ///           If you don't want userdata, pass a void literal {}.
    pub fn linkLibrary(this: Module, library_name: [:0]const u8, comptime library: type, userdata: anytype) !void {

        comptime const decls = std.meta.declarations(library);
        inline for(decls) |decl| {
            switch(decl.data) {
                .Fn => |fninfo| {
                    const fn_name_z = comptime get_name: {
                        var name_buf: [decl.name.len:0]u8 = undefined;
                        std.mem.copy(u8, &name_buf, decl.name);
                        break :get_name name_buf;
                    };
                    try this.linkRawFunction(library_name, &fn_name_z, @field(library, decl.name), userdata);
                },
                else => continue,
            }
        }
    }

    /// Links a native function into the module.
    /// library_name: the name of the library this function should belong to.
    /// function_name: the name the function should have in module-space.
    /// function: a zig function (not function pointer!).
    ///           Valid argument and return types are:
    ///             i32, u32, i64, u64, f32, f64, void, and pointers to basic types.
    ///           Userdata, if provided, is the first argument to the function.
    /// userdata: A single-item pointer passed to the function as the first argument when called.
    ///           Not accessible from within wasm, handled by the interpreter.
    ///           If you don't want userdata, pass a void literal {}.
    pub fn linkRawFunction(
        this: Module,
        library_name: [:0]const u8,
        function_name: [:0]const u8,
        comptime function: anytype,
        userdata: anytype
    ) !void {
        comptime const has_userdata = @TypeOf(userdata) != void;
        comptime validate_userdata: {
            if(has_userdata) {
                switch(@typeInfo(@TypeOf(userdata))) {
                    .Pointer => |ptrti| {
                        if(ptrti.size == .One) {
                            break :validate_userdata;
                        }
                    },
                    else => {},
                }
                @compileError("Expected a single-item pointer for the userdata, got " ++ @typeName(@TypeOf(userdata)));
            }
        }
        const UserdataType = @TypeOf(userdata);
        const sig = comptime generate_signature: {
            switch(@typeInfo(@TypeOf(function))) {
                .Fn => |fnti| {
                    const sub_data = if(has_userdata) 1 else 0;
                    var arg_str: [fnti.args.len + 3 - sub_data:0]u8 = undefined;
                    arg_str[0] = mapTypeToChar(fnti.return_type orelse void);
                    arg_str[1] = '(';
                    arg_str[arg_str.len - 1] = ')';
                    for(fnti.args[sub_data..]) |arg, i| {
                        if(arg.is_generic) {
                            @compileError("WASM does not support generic arguments to native functions!");
                        }
                        arg_str[2 + i] = mapTypeToChar(arg.arg_type.?);
                    }
                    break :generate_signature arg_str;
                },
                else => @compileError("Expected a function, got " ++ @typeName(@TypeOf(function))),
            }
            unreachable;
        };
        const lambda = struct{pub fn l(rt: c.IM3Runtime, sp: [*c]u64, _mem: ?*c_void, arg_userdata: ?*c_void) callconv(.C) ?*const c_void {

            comptime var type_arr: []const type = &[0]type{};
            if(has_userdata) {
                type_arr = type_arr ++ @as([]const type, &[1]type{UserdataType});
            }
            var mem = @ptrToInt(_mem);
            var stack = @ptrToInt(sp);
            const stride = @sizeOf(u64) / @sizeOf(u8);

            switch(@typeInfo(@TypeOf(function))) {
                .Fn => |fnti| {


                    const RetT = fnti.return_type orelse void;

                    const ret_is_localptr = switch(@typeInfo(RetT)) {
                        .Struct => @hasDecl(RetT, "_is_wasm3_local_ptr"),
                        else => false,
                    };

                    const RetPtr = if(RetT == void) void else if(ret_is_localptr) *RetT.Base else *RetT;
                    var ret_val: RetPtr = undefined;
                    if(RetT != void) {
                        ret_val = @intToPtr(*RetT, stack);
                    }
                    
                    const sub_data = if(has_userdata) 1 else 0;
                    inline for(fnti.args[sub_data..]) |arg, i| {
                        if(arg.is_generic) unreachable;

                        type_arr = type_arr ++ @as([]const type, &[1]type{arg.arg_type.?});
                    }

                    var args: std.meta.Tuple(type_arr) = undefined;

                    comptime var idx: usize = 0;
                    if(has_userdata) {
                        args[idx] = @ptrCast(UserdataType, @alignCast(@alignOf(std.meta.Child(UserdataType)), arg_userdata));
                        idx += 1;
                    }
                    inline for(fnti.args[sub_data..]) |arg, i| {
                        if(arg.is_generic) unreachable;

                        const ArgT = arg.arg_type.?;

                        const is_ptr = switch(@typeInfo(ArgT)) {
                            .Struct => @hasDecl(ArgT, "_is_wasm3_local_ptr"),
                            else => false,
                        };
                        if(is_ptr) {

                            args[idx] = ArgT{.local_heap = mem, .host_ptr = @intToPtr(*ArgT.Base, mem + @intToPtr(*u32, stack).*)};
                        } else {
                            args[idx] = @intToPtr(*ArgT, stack).*;
                        }
                        idx += 1;
                        stack += stride;
                    }

                    if(RetT == void) {
                        @call(.{.modifier = .always_inline}, function, args);
                    } else {
                        const returned_value = @call(.{.modifier = .always_inline}, function, args);
                        if(ret_is_localptr) {
                            ret_val.* = returned_value.localPtr();
                        } else {
                            ret_val.* = returned_value;
                        }
                    }

                    return c.m3Err_none;
                },
                else => unreachable,
            }
        }}.l;
        try mapError(c.m3_LinkRawFunctionEx(this.impl, library_name, function_name, @as([*]const u8, &sig), lambda, if(has_userdata) userdata else null));
    }
};

pub const Environment = struct {

    impl: c.IM3Environment,

    pub inline fn init() Environment {
        return .{.impl = c.m3_NewEnvironment()};
    }
    pub inline fn deinit(this: Environment) void {
        c.m3_FreeEnvironment(this.impl);
    }
    pub inline fn createRuntime(this: Environment, stack_size: u32, userdata: ?*c_void) Runtime {
        return .{.impl = c.m3_NewRuntime(this.impl, stack_size, userdata)};
    }
    pub inline fn parseModule(this: Environment, wasm: []const u8) !Module {
        var mod = Module {.impl = undefined};
        var res = c.m3_ParseModule(this.impl, &mod.impl, wasm.ptr, @intCast(u32, wasm.len));
        try mapError(res);
        return mod;
    }
};

pub inline fn yield() !void {
    return mapError(c.m3_Yield());
}
pub inline fn printM3Info() void {
    c.m3_PrintM3Info();
}
pub inline fn printProfilerInfo() void {
    c.m3_PrintProfilerInfo();
}