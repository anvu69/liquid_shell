Pod::Spec.new do |s|
  s.name             = 'liquid_shell_ios'
  s.version          = '0.1.0'
  s.summary          = 'iOS signals for the liquid_shell Flutter plugin.'
  s.description      = <<-DESC
Streams Reduce Transparency to liquid_shell so its glass can fall back to a solid fill.
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
