#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <fstream>
#include <fcntl.h>
#include <io.h>
#include <shaderc/shaderc.hpp>

// Helper function to determine shader kind from given type string
shaderc_shader_kind getShaderKind(const std::string& type) {
    if (type == "vertex") return shaderc_vertex_shader;
    if (type == "fragment") return shaderc_fragment_shader;
    if (type == "compute") return shaderc_compute_shader;
    if (type == "geometry") return shaderc_geometry_shader;
    if (type == "tess_control") return shaderc_tess_control_shader;
    if (type == "tess_evaluation") return shaderc_tess_evaluation_shader;
    return shaderc_glsl_infer_from_source;
}
int main(int argc, char* argv[]) {
    #ifdef _WIN32
    	_setmode(_fileno(stdout), _O_BINARY);
    #endif
    
    // Default to inferring shader type from source
    shaderc_shader_kind shaderKind = shaderc_glsl_infer_from_source;
    bool optimize = false;
    std::string inputName = "shader";
    std::string inputFile = "";
    
    // Parse command line args
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "-t" && i + 1 < argc) {
            shaderKind = getShaderKind(argv[++i]);
        } else if (arg == "-O") {
            optimize = true;
        } else if (arg == "-n" && i + 1 < argc) {
            inputName = argv[++i];
        } else if (arg == "-f" && i + 1 < argc) {
            inputFile = argv[++i];
        }
    }


    // Read shader source from file or stdin
    std::string shaderSource;
    if (!inputFile.empty()) {
        std::ifstream file(inputFile);
        if (!file) {
            std::cerr << "Error: Could not open file: " << inputFile << std::endl;
            return 1;
        }
        std::stringstream buffer;
        buffer << file.rdbuf();
        shaderSource = buffer.str();
    } else {
        // Fallback to stdin if no file specified
        std::stringstream buffer;
        buffer << std::cin.rdbuf();
        shaderSource = buffer.str();
    }
    
    if (shaderSource.empty()) {
        std::cerr << "Error: No shader source provided" << std::endl;
        return 1;
    }

    // Initialize shaderc compiler
    shaderc::Compiler compiler;
    shaderc::CompileOptions options;
    
    // Set optimization level if requested
    if (optimize) {
        options.SetOptimizationLevel(shaderc_optimization_level_performance);
    }

    // Compile the shader
    shaderc::SpvCompilationResult result = compiler.CompileGlslToSpv(
        shaderSource, shaderKind, inputName.c_str(), options);

    auto status = result.GetCompilationStatus();
    if (status != shaderc_compilation_status_success) {
        std::cerr << "Compilation error (status code: " << status << ")" << std::endl;
        std::cerr << "Error message: \"" << result.GetErrorMessage() << "\"" << std::endl;
        
        // Ensure output is flushed
        std::cerr.flush();
        return 1;
    }

    // Write the binary SPIR-V to stdout
    std::vector<uint32_t> spirv(result.cbegin(), result.cend());
    std::cout.write(reinterpret_cast<const char*>(spirv.data()), 
                   spirv.size() * sizeof(uint32_t));
    
    return 0;
}