require_relative 'aapt'
require_relative 'wait'
require 'open3'

class Adb
  include Wait

  def initialize(serial, logger)
    wait(10, 'No devices, connect device please') { devices.first }
    @serial = serial || devices.first
    @logger = logger
  end

  def adb(command)
    command = "adb -s #{@serial} #{command}"

    @logger.info("[ADB]: #{command}") if @logger

    stdout, stderr, status = Open3.capture3(command)
    if !stderr.empty? && !stderr.include?('Success')
      raise "#{command} failed with message \n #{stderr}"
    end
    return stdout
  end

  def devices
    parts = []
    `adb devices`.lines.each do |line|
      line.strip!
      if (!line.empty? && line !~ /^List of devices/)
        parts.push line.split.first
      end
    end
    parts
  end

  def restart_adb
    `adb kill-server`
    `adb start-server`
  end

  def install(path)
    if already_installed? Aapt.package_name(path)
      adb "install -r #{path}"
    else
      adb "install #{path}"
    end
  end

  def already_installed?(package_name)
    out = exec_command("pm list packages #{package_name}")
    !out.empty?
  end

  def uninstall(package_name)
    if already_installed? package_name
      adb "uninstall #{package_name}"
    end
  end

  def reinstall(path)
    uninstall(Aapt.package_name(path))
    install(path)
  end

  def exec_command(command)
    adb "shell exec #{command}"
  end

  def pull(source_path, out_path)
    adb "pull #{source_path} #{out_path}"
  end

  def take_screenshot(path)
    exec_command 'screencap -p /sdcard/screenshot.png'
    pull '/sdcard/screenshot.png', path
  end

  def take_screen_source
    exec_command 'uiautomator dump /sdcard/source.xml'
    pull '/sdcard/source.xml', 'temp/current_source.xml'
    source = File.read('temp/current_source.xml')
  end

  def launch_package(package)
    exec_command "monkey -p #{package} 1"
  end

  def launch_package_with_activity(package, activity)
    exec_command "am start -n #{package}/#{activity}"
  end

  def get_current_activity
    out = exec_command 'dumpsys window windows'
    package, activity = out.lines.grep(/mCurrentFocus/).first[/ (\S*)}/, 1].split('/')
  end
end
