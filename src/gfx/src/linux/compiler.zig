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
    compiler_path: []const u8 = "../compiler/bin/shader_compiler",

    pub fn init(allocator: Allocator) !*ShaderCompiler {
        const self = try allocator.create(ShaderCompiler);
        self.* = .{
            .allocator = allocator,
            .shader_cache = std.StringHashMap(vk.ShaderModule).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *ShaderCompiler) void {
        // Destroy all cached shader modules
        var it = self.shader_cache.iterator();
        while (it.next()) |entry| {
            if (self.device) |device| {
                vk.destroyShaderModule(device, entry.value_ptr.*, null);
            }
            self.allocator.free(entry.key_ptr.*);
        }
        self.shader_cache.deinit();
        self.allocator.destroy(self);
    }

    pub fn setDevice(self: *ShaderCompiler, device: vk.Device) void {
        self.device = device;
    }
    pub fn compileGlslToModule(self: *ShaderCompiler, source: []const u8, shader_type: ShaderType) !vk.ShaderModule {
        const tag = @tagName(shader_type);
        const lowercase_tag = try std.ascii.allocLowerString(self.allocator, tag);
        defer self.allocator.free(lowercase_tag);

        // Create a temporary file for the shader source
        // Use mktemp to create a temporary file
        const mktemp_result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{
                "mktemp",
                "shader_XXXXXX.glsl",
            },
            .max_output_bytes = 4096,
        });
        defer self.allocator.free(mktemp_result.stdout);
        defer self.allocator.free(mktemp_result.stderr);

        if (mktemp_result.term.Exited != 0) {
            std.debug.print("mktemp command failed: {s}\n", .{mktemp_result.stderr});
            return error.MkTempFailed;
        }

        // Extract filename from path, removing trailing newline
        const tmp_filename = std.mem.trimRight(u8, mktemp_result.stdout, "\n");

        // Get the current working directory to create an absolute path
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const cwd = try std.fs.cwd().realpath(".", &path_buffer);

        // Create absolute path
        const full_tmp_path = try std.fs.path.join(self.allocator, &[_][]const u8{ cwd, tmp_filename });
        defer self.allocator.free(full_tmp_path);

        // Open the file created by mktemp
        std.debug.print("opening {s}", .{full_tmp_path});
        const tmp_file = try std.fs.openFileAbsolute(full_tmp_path, .{ .mode = .write_only });
        defer {
            tmp_file.close();
            // Delete the temp file when done
            std.fs.deleteFileAbsolute(full_tmp_path) catch |err| {
                std.debug.print("Warning: Failed to delete temp file: {any}\n", .{err});
            };
        }

        try tmp_file.writeAll(source);
        try tmp_file.sync(); // Ensure data is written to disk

        // Get the full path to the temp file
        const tmp_path = try std.fmt.allocPrint(self.allocator, "{s}", .{tmp_filename});
        defer self.allocator.free(tmp_path);

        // Spawn the shader compiler with the file path
        var child = process.Child.init(&[_][]const u8{
            self.compiler_path,
            "-t",
            lowercase_tag,
            "-f",
            tmp_path,
        }, self.allocator);

        // Set up safer stream handling
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        std.debug.print("spawning", .{});
        try child.spawn();
        // Prepare buffers for stdout and stderr
        var stdout_buffer = std.ArrayListUnmanaged(u8).initCapacity(self.allocator, 8192) catch |err| {
            std.debug.print("Error initializing stdout buffer: {any}\n", .{err});
            return err;
        };
        defer stdout_buffer.deinit(self.allocator);

        var stderr_buffer = std.ArrayListUnmanaged(u8).initCapacity(self.allocator, 8192) catch |err| {
            std.debug.print("Error initializing stderr buffer: {any}\n", .{err});
            return err;
        };
        defer stderr_buffer.deinit(self.allocator);

        // Read stdout and stderr before waiting
        child.collectOutput(self.allocator, &stdout_buffer, &stderr_buffer, 8192) catch |err| {
            std.debug.print("Error collecting output: {any}\n", .{err});
            return err;
        };

        const term = child.wait() catch |err| {
            std.debug.print("Error waiting for child process: {any}\n", .{err});
            return err;
        };

        if (term.Exited != 0) {
            std.debug.print("Shader compiler exited with error: {s}\n", .{stderr_buffer.items});
            return error.ShaderCompilationFailed;
        }

        // Process the SPIR-V data from stdout
        const spirv_data = stdout_buffer;

        // Verify SPIR-V size is valid
        if (spirv_data.items.len % 4 != 0) {
            std.debug.print("Invalid SPIR-V binary size: not a multiple of 4 bytes\n", .{});
            return error.InvalidSpirV;
        }

        // Create shader module from SPIR-V data
        const create_info = vk.ShaderModuleCreateInfo{
            .sType = vk.sTy(vk.StructureType.ShaderModuleCreateInfo),
            .codeSize = spirv_data.items.len,
            .pCode = @ptrCast(@alignCast(spirv_data.items.ptr)),
        };

        var shader_module: vk.ShaderModule = undefined;
        const result = vk.createShaderModule(self.device.?, &create_info, null, &shader_module);
        if (result != vk.SUCCESS) {
            return error.ShaderModuleCreationFailed;
        }

        std.debug.print("Shader compiled successfully: {s}\n", .{tag});

        return shader_module;
    }

    /// Compile GLSL source to a shader module and store it in cache
    pub fn compileAndCacheShader(self: *ShaderCompiler, source: []const u8, shader_type: ShaderType, name: []const u8, cache_key: []const u8) !vk.ShaderModule {
        // Check cache first
        if (self.shader_cache.get(cache_key)) |module| {
            return module;
        }

        // Compile the shader
        const shader_module = try self.compileGlslToModule(source, shader_type);

        // Store in cache
        const key_copy = try self.allocator.dupe(u8, cache_key);
        errdefer self.allocator.free(key_copy);
        try self.shader_cache.put(key_copy, shader_module);

        std.debug.print("Compiled and cached shader: {s}\n", .{name});
        return shader_module;
    }

    pub fn debugShaderPath(path: []const u8) !void {
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const cwd = try std.fs.cwd().realpath(".", &path_buffer);
        std.debug.print("Current working directory: {s}\n", .{cwd});
        std.debug.print("Looking for shader at: {s}\n", .{path});

        // Check if file exists
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            std.debug.print("Failed to open shader file: {any}\n", .{err});
            return err;
        };
        defer file.close();

        const stat = try file.stat();
        std.debug.print("Found shader, size: {d} bytes\n", .{stat.size});
        return;
    }

    /// Compile a shader file from GLSL to SPIR-V and load it
    pub fn compileShaderFile(self: *ShaderCompiler, glsl_path: []const u8, shader_type: ShaderType) !vk.ShaderModule {
        try ShaderCompiler.debugShaderPath(glsl_path);
        // Read the GLSL file
        const file = try fs.cwd().openFile(glsl_path, .{});
        defer file.close();

        // Get file size and allocate buffer
        const file_size = try file.getEndPos();
        const source = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(source);

        // Read the file
        const bytes_read = try file.readAll(source);
        if (bytes_read != file_size) {
            return error.IncompleteRead;
        }

        // Use the file path as both name and cache key
        return self.compileAndCacheShader(source, shader_type, glsl_path, glsl_path);
    }
    /// Load a shader file from the filesystem
    fn loadShaderFile(self: *ShaderCompiler, path: []const u8) ![]align(@alignOf(u32)) u8 {
        const file = try fs.cwd().openFile(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        if (file_size % 4 != 0) {
            std.debug.print("Warning: SPIR-V shader size is not a multiple of 4 bytes\n", .{});
        }

        // Allocate aligned memory for the shader code
        const shader_code = try self.allocator.alignedAlloc(u8, @alignOf(u32), file_size);
        errdefer self.allocator.free(shader_code);

        const bytes_read = try file.readAll(shader_code);
        if (bytes_read != file_size) {
            return error.IncompleteRead;
        }

        return shader_code;
    }

    /// Remove a shader from the cache
    pub fn removeShader(self: *ShaderCompiler, path: []const u8) void {
        if (self.shader_cache.fetchRemove(path)) |entry| {
            if (self.device) |device| {
                vk.destroyShaderModule(device, entry.value, null);
            }
            self.allocator.free(entry.key);
        }
    }

    /// Clear all shaders from the cache
    pub fn clearShaders(self: *ShaderCompiler) void {
        var it = self.shader_cache.iterator();
        while (it.next()) |entry| {
            if (self.device) |device| {
                vk.destroyShaderModule(device, entry.value_ptr.*, null);
            }
            self.allocator.free(entry.key_ptr.*);
        }
        self.shader_cache.clearAndFree();
    }
};
