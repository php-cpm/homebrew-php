require File.expand_path("../../Abstract/abstract-php-extension", __FILE__)

class Php71Phpiredis < PhpExtensionFormula
  init
  desc "PHP extension for Redis based on Hiredis"
  homepage "https://github.com/nrk/phpiredis"
  url "https://github.com/nrk/phpiredis/archive/v1.0.0.tar.gz"
  sha256 "6bd7b1f3d7d830cae64b74136ab0b0f76deaaebcad92027235a59e24cc28387c"
  head "https://github.com/nrk/phpiredis.git"

  bottle do
    cellar :any_skip_relocation
    sha256 "5cc9c5e4adbfa26abe86081bb20517e234195236f0b6a3884c6c365dceda78cd" => :high_sierra
    sha256 "dbcbe4b8f57e17f96a6e6d6b7f8b129fa3ad8985c972454ec28c733a42172bbc" => :sierra
    sha256 "f5346f5e7c7bb33af312ca71c1475365738ba6461436739d24bb5739f24bd033" => :el_capitan
  end

  depends_on "hiredis" => :build

  def install
    args = []
    args << "--enable-phpiredis"

    safe_phpize

    system "./configure", phpconfig, *args
    system "make"

    prefix.install "modules/phpiredis.so"
  end
end
