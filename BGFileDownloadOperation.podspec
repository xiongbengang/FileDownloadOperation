
Pod::Spec.new do |s|
  s.name         = "BGFileDownloadOperation"
  s.version      = '0.0.1'
  s.summary      = "A file download operation use NSURLSession."
  s.description  = <<-DESC
                    A file download operation use NSURLSession which can resume download.
                   DESC
  s.homepage     = "https://github.com/xiongbengang/FileDownloadOperation"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "bengang" => "316379737@qq.com" }
  s.source       = { :git => "https://github.com/xiongbengang/FileDownloadOperation.git", :tag => "#{s.version}",:submodules => true}
  s.source_files = "Classes", "Classes/**/*"
  s.public_header_files = 'Classes/*/**.h'
  s.ios.deployment_target = '7.0'
  s.platform     = :ios, '7.0'

end
