require File.expand_path("../Abstract/abstract-php-extension", __dir__)
 
class Php72Yaconf < AbstractPhp72Extension
  init
  desc "A PHP Persistent Configurations Container"
  homepage "https://github.com/laruence/yaconf"
  url "https://github.com/laruence/yaconf/archive/yaconf-1.0.7.zip"
  sha256 "9a7e558ee84a71d5a4762e515e1af09eebf30535de7d73c0daa1fc8d4c02853c"
  head "https://github.com/laruence/yaconf.git"
 
  def install
    safe_phpize
    system "./configure", "--prefix=#{prefix}",
                          phpconfig
    system "make"
    prefix.install %w[modules/yaconf.so]
    write_config_file if build.with? "config-file"
  end
 
  def config_file
    super + <<~EOS
 
      ; yaconf can be used to store PHP config.
      ; To do this, uncomment and configure below
      ; yaconf.directory = /tmp/yaconf
    EOS
  end
end
