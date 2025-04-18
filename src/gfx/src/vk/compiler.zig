const c = @cImport({
    @cInclude("stdlib.h");
});
const std = @import("std");
const vk = @import("vk.zig");
const Allocator = std.mem.Allocator;
const fs = std.fs;
const process = std.process;

pub const ShaderType = enum {
    Vertex,
    Fragment,
    Compute,
    Geometry,
    TessControl,
    TessEvaluation,
};

/// Simple shader compiler that loads SPIR-V shaders from files
pub const ShaderCompiler = struct {
    allocator: Allocator,
    device: ?vk.Device = null,
    shader_cache: std.StringHashMap(vk.ShaderModule),
    in_progress_shaders: std.StringHashMap(void), // Track shaders currently being compiled
    compiler_path: []const u8 = "./src/compiler/bin/shader_compiler.exe",

    pub fn init(allocator: Allocator) !*ShaderCompiler {
        std.debug.print("ShaderCompiler.init: Starting initialization\n", .{});
        const self = try allocator.create(ShaderCompiler);
        self.* = .{
            .in_progress_shaders = std.StringHashMap(void).init(allocator),
            .allocator = allocator,
            .shader_cache = std.StringHashMap(vk.ShaderModule).init(allocator),
        };
        std.debug.print("ShaderCompiler.init: Successfully initialized\n", .{});
        return self;
    }

    pub fn deinit(self: *ShaderCompiler) void {
        std.debug.print("ShaderCompiler.deinit: Starting deinitialization\n", .{});

        // Destroy all cached shader modules
        var it = self.shader_cache.iterator();
        var count: usize = 0;
        while (it.next()) |entry| {
            if (self.device) |device| {
                std.debug.print("ShaderCompiler.deinit: Destroying shader module for '{s}'\n", .{entry.key_ptr.*});
                vk.destroyShaderModule(device, entry.value_ptr.*, null);
            }
            self.allocator.free(entry.key_ptr.*);
            count += 1;
        }
        std.debug.print("ShaderCompiler.deinit: Destroyed {d} shader modules\n", .{count});

        self.shader_cache.deinit();
        self.allocator.destroy(self);
        std.debug.print("ShaderCompiler.deinit: Completed\n", .{});
    }

    pub fn setDevice(self: *ShaderCompiler, device: vk.Device) void {
        std.debug.print("ShaderCompiler.setDevice: Setting device handle\n", .{});
        self.device = device;
        std.debug.print("ShaderCompiler.setDevice: Device set successfully\n", .{});
    }

    pub fn compileGlslToModule(self: *ShaderCompiler, source: []const u8, shader_type: ShaderType) !vk.ShaderModule {
        std.debug.print("ShaderCompiler.compileGlslToModule: Starting compilation for {s} shader (source length: {d})\n", .{ @tagName(shader_type), source.len });

        const tag = @tagName(shader_type);
        const lowercase_tag = try std.ascii.allocLowerString(self.allocator, tag);
        defer self.allocator.free(lowercase_tag);
        std.debug.print("ShaderCompiler.compileGlslToModule: Using shader type '{s}'\n", .{lowercase_tag});

        // Prepare to spawn the shader compiler process
        std.debug.print("ShaderCompiler.compileGlslToModule: Preparing to spawn compiler process\n", .{});
        std.debug.print("ShaderCompiler.compileGlslToModule: Compiler path: {s}\n", .{self.compiler_path});
        var child = process.Child.init(&[_][]const u8{
            self.compiler_path,
            "-t",
            lowercase_tag,
            "-f",
            "-", // Use "-" to indicate reading from stdin
        }, self.allocator);

        // Set up pipe for stdin, stdout, and stderr
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        std.debug.print("ShaderCompiler.compileGlslToModule: Spawning compiler process\n", .{});
        try child.spawn();

        // Write shader source to stdin
        std.debug.print("ShaderCompiler.compileGlslToModule: Writing shader source to compiler stdin\n", .{});
        try child.stdin.?.writeAll(source);
        child.stdin.?.close();
        child.stdin = null;
        std.debug.print("ShaderCompiler.compileGlslToModule: Source written successfully\n", .{});

        // Prepare buffers for stdout and stderr
        var stdout_buffer = std.ArrayListUnmanaged(u8).initCapacity(self.allocator, 1024 * 1024) catch |err| {
            std.debug.print("ShaderCompiler.compileGlslToModule: Error initializing stdout buffer: {any}\n", .{err});
            return err;
        };
        defer stdout_buffer.deinit(self.allocator);

        var stderr_buffer = std.ArrayListUnmanaged(u8).initCapacity(self.allocator, 1024 * 1024) catch |err| {
            std.debug.print("ShaderCompiler.compileGlslToModule: Error initializing stderr buffer: {any}\n", .{err});
            return err;
        };
        defer stderr_buffer.deinit(self.allocator);

        // Read stdout and stderr
        std.debug.print("ShaderCompiler.compileGlslToModule: Collecting process output\n", .{});
        child.collectOutput(self.allocator, &stdout_buffer, &stderr_buffer, 1024 * 1024) catch |err| {
            std.debug.print("ShaderCompiler.compileGlslToModule: Error collecting output: {any}\n", .{err});
            return err;
        };

        const term = child.wait() catch |err| {
            std.debug.print("ShaderCompiler.compileGlslToModule: Error waiting for child process: {any}\n", .{err});
            return err;
        };

        if (term.Exited != 0) {
            std.debug.print("ShaderCompiler.compileGlslToModule: Shader compiler exited with error: {s}\n", .{stderr_buffer.items});
            return error.ShaderCompilationFailed;
        }

        std.debug.print("ShaderCompiler.compileGlslToModule: Compiler process completed successfully\n", .{});

        // Process the SPIR-V data from stdout
        const spirv_data = stdout_buffer;
        std.debug.print("ShaderCompiler.compileGlslToModule: SPIR-V data size: {d} bytes\n", .{spirv_data.items.len});
        std.debug.print("ShaderCompiler.compileGlslToModule: SPIR-V capacity: {d} bytes\n", .{spirv_data.capacity});

        // Verify SPIR-V size is valid
        if (spirv_data.items.len % 4 != 0) {
            std.debug.print("ShaderCompiler.compileGlslToModule: Invalid SPIR-V binary size: {d} (not a multiple of 4 bytes)\n", .{spirv_data.items.len});
            return error.InvalidSpirV;
        }

        std.debug.print("ShaderCompiler.compileGlslToModule: Creating Vulkan shader module\n", .{});
        // Create shader module from SPIR-V data
        const create_info = vk.ShaderModuleCreateInfo{
            .sType = vk.sTy(vk.StructureType.ShaderModuleCreateInfo),
            .codeSize = spirv_data.items.len,
            .pCode = @ptrCast(@alignCast(spirv_data.items.ptr)),
        };

        var shader_module: vk.ShaderModule = undefined;
        if (self.device == null) {
            std.debug.print("ShaderCompiler.compileGlslToModule: ERROR - Device is null\n", .{});
            return error.DeviceNotSet;
        }

        const result = vk.createShaderModule(self.device.?, &create_info, null, &shader_module);
        if (result != vk.SUCCESS) {
            std.debug.print("ShaderCompiler.compileGlslToModule: Failed to create shader module, Vulkan result: {d}\n", .{result});
            return error.ShaderModuleCreationFailed;
        }

        std.debug.print("ShaderCompiler.compileGlslToModule: Shader compiled successfully: {s}\n", .{tag});
        return shader_module;
    }

    pub fn compileAndCacheShader(self: *ShaderCompiler, source: []const u8, shader_type: ShaderType, name: []const u8, cache_key: []const u8) !vk.ShaderModule {
        std.debug.print("ShaderCompiler.compileAndCacheShader: Processing shader '{s}'\n", .{name});

        // Check cache first
        if (self.shader_cache.get(cache_key)) |module| {
            std.debug.print("ShaderCompiler.compileAndCacheShader: Found in cache, returning existing module for '{s}'\n", .{name});
            return module;
        }

        // Check if this shader is already being compiled - prevent recursion
        if (self.in_progress_shaders.contains(cache_key)) {
            std.debug.print("ShaderCompiler.compileAndCacheShader: Detected recursive shader dependency for '{s}'\n", .{name});
            return error.RecursiveShaderDependency;
        }

        // Mark this shader as in-progress
        const key_temp = try self.allocator.dupe(u8, cache_key);
        defer self.allocator.free(key_temp);
        try self.in_progress_shaders.put(key_temp, {});
        defer _ = self.in_progress_shaders.remove(cache_key);

        std.debug.print("ShaderCompiler.compileAndCacheShader: Not in cache, compiling shader '{s}'\n", .{name});

        // Compile the shader
        const shader_module = try self.compileGlslToModule(source, shader_type);

        // Store in cache
        std.debug.print("ShaderCompiler.compileAndCacheShader: Storing in cache with key '{s}'\n", .{cache_key});
        const key_copy = try self.allocator.dupe(u8, cache_key);
        errdefer self.allocator.free(key_copy);
        try self.shader_cache.put(key_copy, shader_module);

        std.debug.print("ShaderCompiler.compileAndCacheShader: Successfully compiled and cached shader: {s}\n", .{name});
        return shader_module;
    }

    /// Compile a shader file from GLSL to SPIR-V and load it
    pub fn compileShaderFile(self: *ShaderCompiler, glsl_path: []const u8, shader_type: ShaderType) !vk.ShaderModule {
        std.debug.print("ShaderCompiler.compileShaderFile: Starting for path: {s}\n", .{glsl_path});

        // Validate path
        if (glsl_path.len == 0) {
            std.debug.print("ShaderCompiler.compileShaderFile: Error - Empty path provided\n", .{});
            return error.EmptyShaderPath;
        }

        // Simple path cleanup - trim whitespace
        const trimmed_path = std.mem.trim(u8, glsl_path, " \t\r\n");
        std.debug.print("ShaderCompiler.compileShaderFile: Trimmed path: {s}\n", .{trimmed_path});

        // Simple path validation
        if (trimmed_path.len == 0) {
            std.debug.print("ShaderCompiler.compileShaderFile: Error - Path contains only whitespace\n", .{});
            return error.EmptyShaderPath;
        }

        // Check if file exists before attempting to open (using relative path)
        std.fs.cwd().access(trimmed_path, .{}) catch |err| {
            std.debug.print("ShaderCompiler.compileShaderFile: File access check failed: {any}, path: {s}\n", .{ err, trimmed_path });
            return error.ShaderFileNotFound;
        };
        std.debug.print("Found\n", .{});

        // Use the trimmed path directly as the cache key to avoid realpathAlloc
        std.debug.print("ShaderCompiler.compileShaderFile: Using path for caching: {s}\n", .{trimmed_path});

        // Check cache first
        if (self.shader_cache.get(trimmed_path)) |module| {
            std.debug.print("ShaderCompiler.compileShaderFile: Found in cache, returning existing module\n", .{});
            return module;
        }

        // Check if this shader is already being compiled - prevent recursion
        if (self.in_progress_shaders.contains(trimmed_path)) {
            std.debug.print("ShaderCompiler.compileShaderFile: Detected recursive shader dependency\n", .{});
            return error.RecursiveShaderDependency;
        }

        // Mark this shader as in-progress
        const key_temp = try self.allocator.dupe(u8, trimmed_path);
        defer self.allocator.free(key_temp);
        try self.in_progress_shaders.put(key_temp, {});
        defer _ = self.in_progress_shaders.remove(trimmed_path);

        const tag = @tagName(shader_type);
        const lowercase_tag = try std.ascii.allocLowerString(self.allocator, tag);
        defer self.allocator.free(lowercase_tag);
        std.debug.print("ShaderCompiler.compileShaderFile: Using shader type '{s}'\n", .{lowercase_tag});

        // Spawn the compiler process and pass the relative file path directly
        std.debug.print("ShaderCompiler.compileShaderFile: Preparing to spawn compiler process\n", .{});
        std.debug.print("ShaderCompiler.compileShaderFile: Compiler path: {s}\n", .{self.compiler_path});
        var child = process.Child.init(&[_][]const u8{
            self.compiler_path,
            "-t",
            lowercase_tag,
            "-f",
            trimmed_path, // Pass the relative path directly
        }, self.allocator);

        // Set up safer stream handling
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        std.debug.print("ShaderCompiler.compileShaderFile: Spawning compiler process\n", .{});
        try child.spawn();

        // Prepare buffers for stdout and stderr
        var stdout_buffer = std.ArrayListUnmanaged(u8).initCapacity(self.allocator, 1024 * 1024) catch |err| {
            std.debug.print("ShaderCompiler.compileShaderFile: Error initializing stdout buffer: {any}\n", .{err});
            return err;
        };
        defer stdout_buffer.deinit(self.allocator);

        var stderr_buffer = std.ArrayListUnmanaged(u8).initCapacity(self.allocator, 1024 * 1024) catch |err| {
            std.debug.print("ShaderCompiler.compileShaderFile: Error initializing stderr buffer: {any}\n", .{err});
            return err;
        };
        defer stderr_buffer.deinit(self.allocator);

        // Read stdout and stderr before waiting
        std.debug.print("ShaderCompiler.compileShaderFile: Collecting process output\n", .{});
        child.collectOutput(self.allocator, &stdout_buffer, &stderr_buffer, 1024 * 1024) catch |err| {
            std.debug.print("ShaderCompiler.compileShaderFile: Error collecting output: {any}\n", .{err});
            return err;
        };

        const term = child.wait() catch |err| {
            std.debug.print("ShaderCompiler.compileShaderFile: Error waiting for child process: {any}\n", .{err});
            return err;
        };

        if (term.Exited != 0) {
            std.debug.print("ShaderCompiler.compileShaderFile: Shader compiler exited with error: {s}\n", .{stderr_buffer.items});
            return error.ShaderCompilationFailed;
        }

        std.debug.print("ShaderCompiler.compileShaderFile: Compiler process completed successfully\n", .{});

        // Process the SPIR-V data from stdout
        const spirv_data = stdout_buffer;
        std.debug.print("ShaderCompiler.compileShaderFile: SPIR-V data size: {d} bytes\n", .{spirv_data.items.len});
        std.debug.print("ShaderCompiler.compileShaderFile: SPIR-V capacity: {d} bytes\n", .{spirv_data.capacity});

        // Verify SPIR-V size is valid
        if (spirv_data.items.len % 4 != 0) {
            std.debug.print("ShaderCompiler.compileShaderFile: Invalid SPIR-V binary size: {d} (not a multiple of 4 bytes)\n", .{spirv_data.items.len});
            return error.InvalidSpirV;
        }

        std.debug.print("ShaderCompiler.compileShaderFile: Creating Vulkan shader module\n", .{});
        // Create shader module from SPIR-V data
        const create_info = vk.ShaderModuleCreateInfo{
            .sType = vk.sTy(vk.StructureType.ShaderModuleCreateInfo),
            .codeSize = spirv_data.items.len,
            .pCode = @ptrCast(@alignCast(spirv_data.items.ptr)),
        };

        var shader_module: vk.ShaderModule = undefined;
        if (self.device == null) {
            std.debug.print("ShaderCompiler.compileShaderFile: ERROR - Device is null\n", .{});
            return error.DeviceNotSet;
        }

        const result = vk.createShaderModule(self.device.?, &create_info, null, &shader_module);
        if (result != vk.SUCCESS) {
            std.debug.print("ShaderCompiler.compileShaderFile: Failed to create shader module, Vulkan result: {d}\n", .{result});
            return error.ShaderModuleCreationFailed;
        }

        // Store in cache
        std.debug.print("ShaderCompiler.compileShaderFile: Storing in cache\n", .{});
        // Store in cache
        std.debug.print("ShaderCompiler.compileShaderFile: Storing in cache\n", .{});
        //const key_copy = try self.allocator.dupe(u8, trimmed_path);
        //errdefer self.allocator.free(key_copy);
        //try self.shader_cache.put(key_copy, shader_module);
        return shader_module;
    }

    /// Load a shader file from the filesystem
    fn loadShaderFile(self: *ShaderCompiler, path: []const u8) ![]align(@alignOf(u32)) u8 {
        std.debug.print("ShaderCompiler.loadShaderFile: Loading shader from: {s}\n", .{path});

        const file = try fs.cwd().openFile(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        std.debug.print("ShaderCompiler.loadShaderFile: File size: {d} bytes\n", .{file_size});

        if (file_size % 4 != 0) {
            std.debug.print("ShaderCompiler.loadShaderFile: Warning: SPIR-V shader size is not a multiple of 4 bytes\n", .{});
        }

        // Allocate aligned memory for the shader code
        std.debug.print("ShaderCompiler.loadShaderFile: Allocating aligned memory\n", .{});
        const shader_code = try self.allocator.alignedAlloc(u8, @alignOf(u32), file_size);
        errdefer self.allocator.free(shader_code);

        std.debug.print("ShaderCompiler.loadShaderFile: Reading file\n", .{});
        const bytes_read = try file.readAll(shader_code);
        if (bytes_read != file_size) {
            std.debug.print("ShaderCompiler.loadShaderFile: Incomplete read: {d}/{d} bytes\n", .{ bytes_read, file_size });
            return error.IncompleteRead;
        }

        std.debug.print("ShaderCompiler.loadShaderFile: Successfully loaded shader ({d} bytes)\n", .{bytes_read});
        return shader_code;
    }

    /// Remove a shader from the cache
    pub fn removeShader(self: *ShaderCompiler, path: []const u8) void {
        std.debug.print("ShaderCompiler.removeShader: Removing shader: {s}\n", .{path});

        if (self.shader_cache.fetchRemove(path)) |entry| {
            std.debug.print("ShaderCompiler.removeShader: Found shader in cache\n", .{});
            if (self.device) |device| {
                std.debug.print("ShaderCompiler.removeShader: Destroying shader module\n", .{});
                vk.destroyShaderModule(device, entry.value, null);
            } else {
                std.debug.print("ShaderCompiler.removeShader: Device is null, skipping module destruction\n", .{});
            }
            self.allocator.free(entry.key);
            std.debug.print("ShaderCompiler.removeShader: Shader removed successfully\n", .{});
        } else {
            std.debug.print("ShaderCompiler.removeShader: Shader not found in cache\n", .{});
        }
    }

    /// Clear all shaders from the cache
    pub fn clearShaders(self: *ShaderCompiler) void {
        std.debug.print("ShaderCompiler.clearShaders: Clearing all cached shaders\n", .{});

        var count: usize = 0;
        var it = self.shader_cache.iterator();
        while (it.next()) |entry| {
            if (self.device) |device| {
                std.debug.print("ShaderCompiler.clearShaders: Destroying shader module for '{s}'\n", .{entry.key_ptr.*});
                vk.destroyShaderModule(device, entry.value_ptr.*, null);
            }
            self.allocator.free(entry.key_ptr.*);
            count += 1;
        }
        self.shader_cache.clearAndFree();
        std.debug.print("ShaderCompiler.clearShaders: Cleared {d} shaders from cache\n", .{count});
    }
};
