// Stub: datadog_flutter_plugin_desktop uses dart:ffi to load the C SDK directly
// (ddsdkcpp.dll on Windows, libddsdkcpp.so on Linux).
//
// Diagnostic shim: bridges the C SDK's synchronous diagnostic handler callback to
// Dart's NativeCallable.listener, which is async. The shim copies msg->text with
// strdup() before the C SDK reclaims the pointer, then calls the Dart listener with
// the copy. Dart is responsible for freeing the copy via malloc.free().

#include <cstdint>
#include <cstdlib>
#include <cstring>

#if defined(_WIN32)
#define DD_PLUGIN_EXPORT extern "C" __declspec(dllexport)
// MSVC deprecates strdup in favour of _strdup.
#define dd_strdup _strdup
#else
#define DD_PLUGIN_EXPORT extern "C" __attribute__((visibility("default")))
#define dd_strdup strdup
#endif

struct dd_diagnostic_message_t {
  int level;
  const char* text;
};

// Matches NativeCallable.listener's native signature:
//   void Function(Int32 level, Pointer<Char> text)
// Dart owns `text` (a strdup copy) and must free it.
typedef void (*DartDiagnosticListener)(int32_t level, char* text);

// Written once from Dart before the SDK starts; read-only from C SDK threads thereafter.
static DartDiagnosticListener g_dart_listener = nullptr;

// Registered as the C SDK's dd_core_config_set_diagnostic_handler. May be called
// from any thread. Copies msg->text so the Dart listener (async via .listener)
// receives a valid pointer when it eventually fires.
DD_PLUGIN_EXPORT void dd_flutter_diagnostic_handler(
    const dd_diagnostic_message_t* msg, void* /*userdata*/) {
  DartDiagnosticListener listener = g_dart_listener;
  if (!listener || !msg) return;
  char* copy = dd_strdup(msg->text ? msg->text : "");
  listener((int32_t)msg->level, copy);
}

// Called once from Dart (before dd_core_start) to register the NativeCallable.listener
// function pointer. Not thread-safe — must be called before the C SDK starts.
DD_PLUGIN_EXPORT void dd_flutter_set_diagnostic_listener(
    DartDiagnosticListener listener) {
  g_dart_listener = listener;
}

// Dart must call this to free strings allocated by dd_flutter_diagnostic_handler.
// On Windows, using free() from this DLL's own CRT avoids cross-DLL heap crashes.
DD_PLUGIN_EXPORT void dd_flutter_free(void* ptr) {
  free(ptr);
}
