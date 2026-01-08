#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint datadog_flutter_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'datadog_flutter_plugin'
  s.version          = '0.0.1'
  s.summary          = 'Instrument your application with Datadog.'
  s.description      = <<-DESC
Instrument your application with Datadog.
                       DESC
  s.homepage         = 'https://datadoghq.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Datadog' => 'info@datadoghq.com' }
  s.source           = { :path => '.' }
  s.source_files = 'datadog_flutter_plugin/Sources/**/*'
  s.static_framework = true
  s.dependency 'Flutter'
  s.dependency 'DatadogCore', '3.4.0'
  s.dependency 'DatadogLogs', '3.4.0'
  s.dependency 'DatadogRUM', '3.4.0'
  s.dependency 'DatadogInternal', '3.4.0'
  s.dependency 'DatadogCrashReporting', '3.4.0'
  s.dependency 'DictionaryCoder', '1.2.0'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.1'
end
