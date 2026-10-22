cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "datadog_flutter_plugin_desktop")
project(${PROJECT_NAME} LANGUAGES CXX)
cmake_policy(VERSION 3.14...3.25)

# dd-sdk-cpp build options
set(DD_BUILD_SHARED ON CACHE BOOL "" FORCE)
set(DD_CRASH_MODE "noop" CACHE STRING "" FORCE)
set(DD_HTTP_USE_SYSTEM_LIBCURL ON CACHE BOOL "" FORCE)

include(FetchContent)
FetchContent_Declare(dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        develop)
FetchContent_MakeAvailable(dd-sdk-cpp)

set(PLUGIN_NAME "${PROJECT_NAME}_plugin")

# Shim .so: bridges the C SDK's synchronous diagnostic handler to Dart's
# async NativeCallable.listener. Dart loads this by path at runtime via
# DynamicLibrary.open(). Flutter's runner CMake copies it to the output dir
# automatically alongside libddsdkcpp.so.
add_library(${PLUGIN_NAME} SHARED
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/plugin_stub.cpp"
)

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON
)

# FFI plugins must explicitly list all shared libraries — the runner's
# generated_plugins.cmake only appends bundled_libraries for FFI plugins.
set(${PROJECT_NAME}_bundled_libraries
  "$<TARGET_FILE:ddsdkcpp>"
  "$<TARGET_FILE:${PLUGIN_NAME}>"
  PARENT_SCOPE
)
