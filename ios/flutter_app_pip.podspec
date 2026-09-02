Pod::Spec.new do |s|
  s.name             = 'flutter_app_pip'
  s.version          = '0.1.0'
  s.summary          = 'In-app and system Picture-in-Picture for Flutter apps.'
  s.description      = 'A local Flutter plugin for in-app overlay PiP and Android/iOS system Picture-in-Picture.'
  s.homepage         = 'https://gosh.local/flutter_app_pip'
  s.license          = { :type => 'MIT' }
  s.author           = { 'GOSH' => 'dev@gosh.local' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
