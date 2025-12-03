# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

include(FetchContent)

# Project-level configuration.
set(PROJECT_NAME "datadog_flutter_plugin")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "datadog_flutter_plugin_plugin")

# For now, this plugin has no source and uses only FFI calls in to the dd_native library
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/dummy.cpp" "")
list(APPEND PLUGIN_SOURCES
  "${CMAKE_CURRENT_BINARY_DIR}/dummy.cpp"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

FetchContent_Declare(
  Datadog
  GIT_REPOSITORY git@github.com:DataDog/dd-sdk-cpp.git
  GIT_TAG origin/main
)
set(DD_BUILD_SHARED ON)
set(DD_HTTP_USE_SYSTEM_LIBCURL OFF)

FetchContent_MakeAvailable(Datadog)
target_link_libraries(${PLUGIN_NAME} PUBLIC Datadog::dd_native)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(datadog_flutter_plugin_bundled_libraries
  ""
  $<TARGET_FILE:Datadog::dd_native>
  PARENT_SCOPE
)