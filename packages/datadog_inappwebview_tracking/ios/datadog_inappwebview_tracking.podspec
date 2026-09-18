#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint datadog_inappwebview_tracking.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'datadog_inappwebview_tracking'
  s.version          = '0.0.1'
  s.summary          = 'Track `flutter_inappwebview` with Datadog.'
  s.description      = <<-DESC
Track `flutter_inappwebview` with Datadog.
                       DESC
  s.homepage         = 'https://datadoghq.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Datadog' => 'info@datadoghq.com' }
  s.source           = { :path => '.' }
  s.source_files = 'datadog_inappwebview_tracking/Sources/**/*'
  s.dependency 'Flutter'
  s.dependency 'DatadogCore',  '~> 3.0'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
