cmake_minimum_required(VERSION 3.10)
project(angelite_shader_compiler VERSION 0.1.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Include required modules
include(ExternalProject)
include(FetchContent)

# Set output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# Build shaderc from source
set(SHADERC_REPO "https://github.com/google/shaderc.git")
set(SHADERC_TAG "main") # or specify a specific version tag/commit
set(SHADERC_PREFIX "${CMAKE_BINARY_DIR}/external/shaderc")
set(SHADERC_INSTALL "${CMAKE_BINARY_DIR}/external/install")

# Configure shaderc build options
set(SHADERC_BUILD_OPTIONS
    -DSHADERC_SKIP_TESTS=ON
    -DSHADERC_SKIP_EXAMPLES=ON
    -DSHADERC_SKIP_COPYRIGHT_CHECK=ON
    -DSHADERC_ENABLE_SHARED_CRT=ON
    -DCMAKE_INSTALL_PREFIX=${SHADERC_INSTALL}
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
)



# Download and build shaderc
ExternalProject_Add(
    shaderc_external
    GIT_REPOSITORY ${SHADERC_REPO}
    GIT_TAG ${SHADERC_TAG}
    PREFIX ${SHADERC_PREFIX}
    UPDATE_COMMAND ${CMAKE_COMMAND} -E chdir <SOURCE_DIR> python3 utils/git-sync-deps
    CMAKE_ARGS ${SHADERC_BUILD_OPTIONS}
    INSTALL_DIR ${SHADERC_INSTALL}
)
# Make directory for includes and libraries
file(MAKE_DIRECTORY ${SHADERC_INSTALL}/include)
file(MAKE_DIRECTORY ${SHADERC_INSTALL}/lib)

# Define the include and lib directories for the built shaderc
set(SHADERC_INCLUDE_DIRS ${SHADERC_INSTALL}/include)
set(SHADERC_LIB_DIR ${SHADERC_INSTALL}/lib)

# Add our shader compiler executable
add_executable(shader_compiler src/main.cpp)

# Fix source path - adjust the path based on your project structure
target_sources(shader_compiler PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp)

# Add dependency on shaderc_external
add_dependencies(shader_compiler shaderc_external)

# Link with the built shaderc
target_include_directories(shader_compiler PRIVATE ${SHADERC_INCLUDE_DIRS})

# Link against static libs - platform-specific naming
if(WIN32)
    target_link_libraries(shader_compiler PRIVATE 
        ${SHADERC_LIB_DIR}/shaderc_combined.lib)
else()
    target_link_libraries(shader_compiler PRIVATE 
        ${SHADERC_LIB_DIR}/libshaderc_combined.a)
endif()

# Installation
install(TARGETS shader_compiler
        RUNTIME DESTINATION bin)