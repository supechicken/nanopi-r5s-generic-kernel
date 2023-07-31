#!/usr/bin/env ruby
# merge_config: Merge the Android .config (make nanopi5_android_defconfig) and Linux .config (make nanopi5_linux_defconfig),
#               making the kernel compatible with both Android and OpenWrt
#
LINUX_CONFIG      = ARGV[0]
ANDROID_CONFIG    = ARGV[1]
LINUX_CONFIG_IO   = File.open(LINUX_CONFIG, 'r')
ANDROID_CONFIG_IO = File.open(ANDROID_CONFIG, 'r')
NEW_CONFIG_IO     = File.open('.config', 'w')

@current_linux_line = @current_android_line = ''

def specific_option?(linux_config_opt, android_config_opt)
  if linux_config_opt.nil?
    return :android
  elsif android_config_opt.nil?
    return :linux
  end

  if linux_config_opt.empty? || (linux_config_opt.start_with?('#') && !linux_config_opt.include?('is not set'))
    # comment
    #return :android if linux_config_opt.empty?
    return :linux if linux_config_opt.delete_prefix('#').chomp.empty?
    return :linux if linux_config_opt && !system('grep', '-Fxq', linux_config_opt, ANDROID_CONFIG)
  else
    # config
    return :linux if linux_config_opt && !system('grep', '-q', "#{linux_config_opt[/CONFIG_[^=\s]+/]}[= ]", ANDROID_CONFIG)
  end

  if android_config_opt.nil? || (android_config_opt.start_with?('#') && !android_config_opt.include?('is not set'))
    # comment
    #return :linux   if android_config_opt.empty?
    return :android if android_config_opt.to_s.delete_prefix('#').chomp.empty?
    return :android if android_config_opt && !system('grep', '-Fxq', android_config_opt, LINUX_CONFIG)
  else
    # config
    return :android if android_config_opt && !system('grep', '-q', "#{android_config_opt[/CONFIG_[^=\s]+/]}[= ]", LINUX_CONFIG)
  end

  p [LINUX_CONFIG_IO.lineno, linux_config_opt], [ANDROID_CONFIG_IO.lineno, android_config_opt]
  raise StandardError, "\e[0;31m""Both have!!!""\e[0m"
end

def both_have?(config)
  if config.empty? || (config.start_with?('#') && !config.include?('is not set'))
    # comment
    return true if config.delete_prefix('#').chomp.empty?
    return (system('grep', '-Fxq', config, ANDROID_CONFIG) && system('grep', '-Fxq', config, LINUX_CONFIG))
  else
    # config
    return (system('grep', '-q', "#{config[/CONFIG_[^=\s]+/]}[= ]", ANDROID_CONFIG) && system('grep', '-q', "#{config[/CONFIG_[^=\s]+/]}[= ]", LINUX_CONFIG))
  end
end

while (@current_linux_line || @current_android_line)
  @current_linux_line   = LINUX_CONFIG_IO.gets(chomp: true) unless @do_not_cover
  @current_android_line = ANDROID_CONFIG_IO.gets(chomp: true) unless @do_not_cover
  @do_not_cover         = false

  if @current_linux_line && (@current_linux_line.delete_prefix('#').empty? || (@current_linux_line.start_with?('#') && !@current_linux_line.include?('is not set')))
    @current_linux_line = LINUX_CONFIG_IO.gets(chomp: true)
    @do_not_cover = true
    #NEW_CONFIG_IO.puts @current_linux_line
    next
  elsif @current_android_line && (@current_android_line.delete_prefix('#').empty? || (@current_android_line.start_with?('#') && !@current_android_line.include?('is not set')))
    @current_android_line = ANDROID_CONFIG_IO.gets(chomp: true)
    @do_not_cover = true
    #NEW_CONFIG_IO.puts @current_android_line
    next
  end

  if @current_linux_line == @current_android_line
    # if same line
    #warn "Same, pass: #{@current_linux_line}"

    NEW_CONFIG_IO.puts @current_android_line
  else
    linux_current_opt   = @current_linux_line[/CONFIG_[^=\s]+/]
    android_current_opt = @current_android_line[/CONFIG_[^=\s]+/]

    if linux_current_opt && android_current_opt && linux_current_opt == android_current_opt
      # if same config but not same answer
      current_option = linux_current_opt

      #warn <<~EOT
      #  ===
      #  Processing #{current_option}...
      #
      #  Linux:   #{@current_linux_line}
      #  Android: #{@current_android_line}
      #
      #EOT

      if @current_linux_line =~ /\=[ym]$/ || @current_android_line =~ /\=[ym]$/
        if @current_android_line.end_with?('=y') || @current_linux_line.end_with?('=y')
          final = "#{current_option}=y"
        else
          final = "#{current_option}=m"
        end
      else
        final = @current_android_line
      end

      puts "#{@current_linux_line} + #{@current_android_line} = #{final}"
      #warn <<~EOT
      #  Final: #{final}
      #  ===
      #EOT

      NEW_CONFIG_IO.puts final
    else
      # if not same
      #p [@current_linux_line, @current_android_line]
      who_specific = specific_option?(@current_linux_line, @current_android_line)

      until @current_linux_line[/CONFIG_[^=\s]+/] == @current_android_line[/CONFIG_[^=\s]+/] || \
            (@current_linux_line.nil? && @current_android_line.nil?) || \
            both_have?(who_specific == :linux ? @current_linux_line : @current_android_line)

        @do_not_cover = true

        if who_specific == :linux
          # linux specific
          puts "\e[1;33m""Linux specific option: #{@current_linux_line}, line #{LINUX_CONFIG_IO.lineno}""\e[0m"
          NEW_CONFIG_IO.puts @current_linux_line

          @current_linux_line = LINUX_CONFIG_IO.gets(chomp: true)
        else
          # android specific
          puts "\e[1;33m""Android specific option: #{@current_android_line}, line #{ANDROID_CONFIG_IO.lineno}""\e[0m"
          NEW_CONFIG_IO.puts @current_android_line

          @current_android_line = ANDROID_CONFIG_IO.gets(chomp: true)
        end
        #sleep 0.5
      end
    end
  end
end

NEW_CONFIG_IO.close
