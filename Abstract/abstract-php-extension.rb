require "formula"
require File.join(File.dirname(__FILE__), "abstract-php-version")

class UnsupportedPhpApiError < RuntimeError
  def initialize
    super "Unsupported PHP API Version"
  end
end

class InvalidPhpizeError < RuntimeError
  def initialize(installed_php_version, required_php_version)
    super <<~EOS
      Version of phpize (PHP#{installed_php_version}) in $PATH does not support building this extension version (PHP#{required_php_version}). Consider installing  with the `--without-homebrew-php` flag.
    EOS
  end
end

class PhpExtensionFormula < Formula
  def initialize(*)
    super
  end

  def self.init
    extension_dsl
  end

  def install
    cd "ext/#{extension}"
    system php_parent.bin/"phpize"
    system "./configure", *configure_args
    system "make"
    (lib/module_path).install "modules/#{extension}.so"
  end

  def post_install
    ext_config_path = etc/"php"/php_parent.php_version/"conf.d"/"ext-#{extension}.ini"
    if ext_config_path.exist?
      inreplace ext_config_path,
        /#{extension_type}=.*$/, "#{extension_type}=#{opt_lib/module_path}/#{extension}.so"
    else
      ext_config_path.write <<~EOS
        [#{extension}]
        #{extension_type}=#{opt_lib/module_path}/#{extension}.so
      EOS
    end
  end

  test do
    assert_match extension.downcase, shell_output("#{php_parent.opt_bin}/php -m").downcase,
      "failed to find extension in php -m output"
  end

  private

  def php_parent
    self.class.php_parent
  end

  def extension
    self.class.extension
  end

  def extension_type
    # extension or zend_extension
    "extension"
  end

  def module_path
    extension_dir = Utils.popen_read("#{php_parent.opt_bin/"php-config"} --extension-dir").chomp
    php_basename = File.basename(extension_dir)
    "php/#{php_basename}"
  end

  def configure_args
    self.class.configure_args
  end

  class << self
    NAME_PATTERN = /^Php(?:([57])(\d+))?(.+)/
    attr_reader :configure_args, :php_parent, :extension

    def configure_arg(args)
      @configure_args ||= []
      @configure_args.concat(Array(args))
    end

    def extension_dsl
      class_name = name.split("::").last
      m = NAME_PATTERN.match(class_name)
      if m.nil?
        raise "Bad PHP Extension name for #{class_name}"
      elsif m[1].nil?
        parent_name = "php"
      else
        parent_name = "php@" + m.captures[0..1].join(".")
      end

      @php_parent = Formula[parent_name]
      @extension = m[3].gsub(/([a-z])([A-Z])/) do
        Regexp.last_match(1) + "_" + Regexp.last_match(2)
      end.downcase
      @configure_args = %W[
        --with-php-config=#{php_parent.opt_bin/"php-config"}
      ]

      homepage php_parent.homepage + extension
      url php_parent.stable.url
      send php_parent.stable.checksum.hash_type, php_parent.stable.checksum.hexdigest

      depends_on "autoconf" => :build
      depends_on parent_name
    end
  end

  def php_branch
    class_name = self.class.name.split("::").last
    matches = /^Php([5,7])([0-9]+)/.match(class_name)
    if matches
      matches[1] + "." + matches[2]
    else
      raise "Unable to guess PHP branch for #{class_name}"
    end
  end

  def php_formula
    "php" + php_branch.sub(".", "")
  end

  def safe_phpize
    ENV["PHP_AUTOCONF"] = "#{Formula["autoconf"].opt_bin}/autoconf"
    ENV["PHP_AUTOHEADER"] = "#{Formula["autoconf"].opt_bin}/autoheader"
    system phpize
  end

  def phpize
    if build.without? "homebrew-php"
      "phpize"
    else
      "#{Formula[php_formula].opt_bin}/phpize"
    end
  end

  def phpini
    if build.without? "homebrew-php"
      "php.ini presented by \"php --ini\""
    else
      "#{Formula[php_formula].config_path}/php.ini"
    end
  end

  def phpconfig
    if build.without? "homebrew-php"
      ""
    else
      "--with-php-config=#{Formula[php_formula].opt_bin}/php-config"
    end
  end

  def extension
    class_name = self.class.name.split("::").last
    matches = /^Php[5,7][0-9](.+)/.match(class_name)
    if matches
      matches[1].downcase
    else
      raise "Unable to guess PHP extension name for #{class_name}"
    end
  end

  def extension_type
    # extension or zend_extension
    "extension"
  end

  def module_path
    opt_prefix / "#{extension}.so"
  end

  def config_file
    <<~EOS
      [#{extension}]
      #{extension_type}="#{module_path}"
      EOS
  rescue StandardError
    nil
  end

  test do
    assert shell_output("#{Formula[php_formula].opt_bin}/php -m").downcase.include?(extension.downcase), "failed to find extension in php -m output"
  end

  def caveats
    caveats = ["To finish installing #{extension} for PHP #{php_branch}:"]

    if build.without? "config-file"
      caveats << "  * Add the following line to #{phpini}:\n"
      caveats << config_file
    else
      caveats << "  * #{config_scandir_path}/#{config_filename} was created,"
      caveats << "    do not forget to remove it upon extension removal."
    end

    caveats << <<-EOS
  * Validate installation via one of the following methods:
  *
  * Using PHP from a webserver:
  * - Restart your webserver.
  * - Write a PHP page that calls "phpinfo();"
  * - Load it in a browser and look for the info on the #{extension} module.
  * - If you see it, you have been successful!
  *
  * Using PHP from the command line:
  * - Run `php -i "(command-line 'phpinfo()')"`
  * - Look for the info on the #{extension} module.
  * - If you see it, you have been successful!
EOS

    caveats.join("\n")
  end

  def config_path
    etc / "php" / php_branch
  end

  def config_scandir_path
    config_path / "conf.d"
  end

  def config_filename
    "ext-" + extension + ".ini"
  end

  def config_filepath
    config_scandir_path / config_filename
  end

  def write_config_file
    if config_filepath.file?
      inreplace config_filepath do |s|
        s.gsub!(/^(;)?(\s*)(zend_)?extension=.+$/, "\\1\\2#{extension_type}=\"#{module_path}\"")
      end
    elsif config_file
      config_scandir_path.mkpath
      config_filepath.write(config_file)
    end
  end
end
