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
    pub inline fn call(this: Function, args: anytype) !void {
        const ArgsType = @TypeOf(args);
        if (@typeInfo(ArgsType) != .Struct) {
            @compileError("Expected tuple or struct argument, found " ++ @typeName(ArgsType));
        }
        const fields_info = std.meta.fields(ArgsType);

        const count = fields_info.len;
        var arg_arr: [count]*c_void = undefined;
        inline for(args) |*a, i| {
            arg_arr = @ptrCast(*c_void, a);
        }
        const arg_arr_slc: []*c_void = &arg_arr;
        return mapError(c.m3_CallWithArgs(this.impl, @intCast(u32, count), @ptrCast([*c][*c]u8, arg_arr_slc.ptr)));
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
            i32 =>  return 'i',
            i64 =>  return 'I',
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

    pub fn linkRawFunction(
        this: Module,
        module_name: [:0]const u8,
        function_name: [:0]const u8,
        comptime function: anytype,
        userdata: anytype
    ) !void {
        const has_userdata = @TypeOf(userdata) != void;
        comptime validate_userdata: {
            if(has_userdata) {
                switch(@typeInfo(@TypeOf(userdata))) {
                    .Pointer => |ptrti| {
                        if(ptrti.size == .One) {
                            break :validate_userdata;
                        }
                    }
                }
                @compileError("Expected a single-item pointer for the userdata, got " ++ @typeName(@TypeOf(userdata)));
            }
        }
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
                type_arr = type_arr ++ @as([]const type, &[1]type{@TypeOf(userdata)});
            }
            var mem = @ptrToInt(_mem);
            var stack = @ptrToInt(sp);
            const stride = @sizeOf(u64) / @sizeOf(u8);

            switch(@typeInfo(@TypeOf(function))) {
                .Fn => |fnti| {

                    const RetT = fnti.return_type orelse void;
                    const RetPtr = if(RetT == void) void else *RetT;
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
                        args[idx] = @ptrCast(@TypeOf(userdata), @alignCast(@alignOf(std.meta.Child(userdata)), arg_userdata));
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
                        ret_val.* = @call(.{.modifier = .always_inline}, function, args);
                    }

                    return c.m3Err_none;
                },
                else => unreachable,
            }
        }}.l;
        try mapError(c.m3_LinkRawFunctionEx(this.impl, module_name, function_name, @as([*]const u8, &sig), lambda, if(has_userdata) userdata else null));
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