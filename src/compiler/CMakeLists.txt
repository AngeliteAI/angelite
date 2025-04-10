cmake_minimum_required(VERSION 3.10)
project(angelite_shader_compiler VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)

# Set C++ standard
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Include required modules
include(ExternalProject)
include(FetchContent)

# Set output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# Add Windows-specific settings
if(WIN32)
    # Use multi-threaded runtime library for Windows
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
    # Disable some warnings on MSVC
    if(MSVC)
        add_compile_options(/W3 /MP /bigobj)
    endif()
endif()

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

# Add Windows-specific options for shaderc
if(WIN32)
    list(APPEND SHADERC_BUILD_OPTIONS
        -DCMAKE_SYSTEM_VERSION=${CMAKE_SYSTEM_VERSION}
        -DCMAKE_VS_PLATFORM_NAME=${CMAKE_VS_PLATFORM_NAME}
        -DCMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}
        -DCMAKE_CXX_FLAGS="-D_CRT_SECURE_NO_WARNINGS ${CMAKE_CXX_FLAGS}"
        -DCMAKE_C_FLAGS="-D_CRT_SECURE_NO_WARNINGS ${CMAKE_C_FLAGS}"
        -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
        -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    )
endif()

# Find Python interpreter (compatibility with both Windows and Unix)
find_package(Python COMPONENTS Interpreter)
if(NOT Python_FOUND)
    find_package(PythonInterp)
    if(PYTHONINTERP_FOUND)
        set(PYTHON_EXECUTABLE ${PYTHON_EXECUTABLE})
    else()
        message(FATAL_ERROR "Python interpreter not found. Please install Python.")
    endif()
else()
    set(PYTHON_EXECUTABLE ${Python_EXECUTABLE})
endif()

# Download and build shaderc
ExternalProject_Add(
    shaderc_external
    GIT_REPOSITORY ${SHADERC_REPO}
    GIT_TAG ${SHADERC_TAG}
    PREFIX ${SHADERC_PREFIX}
    UPDATE_COMMAND ${CMAKE_COMMAND} -E chdir <SOURCE_DIR> ${PYTHON_EXECUTABLE} utils/git-sync-deps
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
list(APPEND SHADERC_BUILD_OPTIONS -DBUILD_SHARED_LIBS=ON)
message(STATUS "Checking for shaderc library at: ${SHADERC_LIB_DIR}/shaderc_combined.lib")
if(EXISTS "${SHADERC_LIB_DIR}/shaderc_combined.lib")
    message(STATUS "Found shaderc library.")
else()
    message(STATUS "Shaderc library NOT found.")
endif()
# Link against static libs - platform-specific naming
target_link_directories(shader_compiler PRIVATE ${SHADERC_LIB_DIR})
if(WIN32)
    # Check both potential Windows library locations
    if(EXISTS "${SHADERC_LIB_DIR}/shaderc_combined.lib")
        target_link_libraries(shader_compiler PRIVATE shaderc_combined.lib)
    else()
        message(WARNING "shaderc_combined.lib not found in expected locations")
    endif()
else()
    # Unix systems
    if(EXISTS "${SHADERC_LIB_DIR}/libshaderc_combined.a")
        target_link_libraries(shader_compiler PRIVATE libshaderc_combined.a)
    else()
        target_link_libraries(shader_compiler PRIVATE shaderc_combined)
    endif()
endif()

# Installation
install(TARGETS shader_compiler
        RUNTIME DESTINATION bin)
