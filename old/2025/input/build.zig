const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Add the input include module
    const input_include_module = b.addModule("include", .{
        .root_source_file = b.path("include/mod.zig"),
    });
    
    // Add the surface include module
    const surface_include_module = b.addModule("surface_include", .{
        .root_source_file = b.path("../surface/include/mod.zig"),
    });
    
    // Add the surface module with its dependency
    const surface_module = b.addModule("surface", .{
        .root_source_file = b.path("../surface/src/lib.zig"),
    });
    
    // Connect the surface module to its include module
    surface_module.addImport("include", surface_include_module);
    
    // Create the input library
    const lib = b.addSharedLibrary(.{
        .name = "input",
        .root_source_file = b.path("src/win32/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    // Add dependencies to the library
    lib.root_module.addImport("include", input_include_module);
    lib.root_module.addImport("surface", surface_module);
    
    // Add necessary system libraries
    lib.linkLibC();
    
    if (target.result.os.tag == .windows) {
        lib.linkSystemLibrary("kernel32");
        lib.linkSystemLibrary("user32");
        // Export all functions
        lib.linker_allow_shlib_undefined = true;
        lib.dll_export_fns = true;
    }
    
    // Install the library
    b.installArtifact(lib);
}