Pod::Spec.new do |s|

  s.name         = "STFTPNetwork"
  s.version      = "0.0.1"
  s.summary      = "An FTP network library for iOS."
  s.homepage     = "https://github.com/shien7654321/STFTPNetwork"
  s.author       = { "Suta" => "shien7654321@163.com" }
  s.source       = { :git => "https://github.com/shien7654321/STFTPNetwork.git", :tag => s.version.to_s }
  s.platform     = :ios, "8.0"
  s.requires_arc = true
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.frameworks   = "Foundation", "UIKit"
  s.source_files = "STFTPNetwork/*.{h,m}"
  s.compiler_flags = "-fmodules"
  s.description    = <<-DESC
  STFTPNetwork is an FTP network library for iOS.
                       DESC

end
