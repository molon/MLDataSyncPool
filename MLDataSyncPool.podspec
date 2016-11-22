Pod::Spec.new do |s|
s.name         = "MLDataSyncPool"
s.version      = "0.0.1"
s.summary      = "Simple data sync pool"

s.homepage     = 'https://github.com/molon/MLDataSyncPool'
s.license      = { :type => 'MIT'}
s.author       = { "molon" => "dudl@qq.com" }

s.source       = {
:git => "https://github.com/molon/MLDataSyncPool.git",
:tag => "#{s.version}"
}

s.platform     = :ios, '7.0'
s.public_header_files = 'Classes/**/*.h'
s.source_files  = 'Classes/**/*.{h,m,c}'
s.requires_arc  = true

end
