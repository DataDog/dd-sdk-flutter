#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint xyz_mac.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
    s.name             = 'datadog_flutter_plugin'
    s.version          = '0.0.1'
    s.summary          = 'A new Flutter FFI plugin project.'
    s.description      = <<-DESC
  A new Flutter FFI plugin project.
                         DESC
    s.homepage         = 'http://example.com'
    s.license          = { :file => '../LICENSE' }
    s.author           = { 'Your Company' => 'email@example.com' }
  
    s.source           = { :path => '.' }
    s.source_files     = 'Classes/**/*'
    s.vendored_libraries = 'libdd_native_rum.dylib'
    s.library = 'dd_native_rum'
    s.dependency 'FlutterMacOS'
  
    s.platform = :osx, '10.11'
    s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
    s.swift_version = '5.0'
  end
  