#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint datadog_webview_tracking.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'datadog_webview_tracking'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for Datadog webview tracking.'
  s.description      = <<-DESC
A Flutter plugin for use with the Datadog Flutter Plugin to track webviews as part of a user's mobile session.
                       DESC
  s.homepage         = 'https://datadoghq.com'
  s.license          = { :type => "Apache", :file => '../LICENSE' }
  s.authors          = { "Jeff Ward" => "jeff.ward@datadoghq.com" }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'DatadogWebViewTracking', '~> 2'
  s.dependency 'webview_flutter_wkwebview'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
