Pod::Spec.new do |s|
  s.name             = 'liquid_shell_ios'
  s.version          = '0.1.0-dev.3'
  s.summary          = 'iOS side of the liquid_shell Flutter plugin.'
  s.description      = <<-DESC
Streams Reduce Transparency to liquid_shell, installs the native iOS 26
tab bar and sidebar on iPhone and iPad, and reads the iPadOS window controls.
                       DESC
  s.homepage         = 'https://github.com/anvu69/liquid_shell'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'lasoai.vn' => 'lasotuviai@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'liquid_shell_ios/Sources/liquid_shell_ios/**/*.swift'
  s.resource_bundles = { 'liquid_shell_ios_privacy' => ['liquid_shell_ios/Sources/liquid_shell_ios/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
