require_relative 'wait'
require 'open3'
require 'jsonrpc-client'

class Adb
  include Wait

  def initialize(capabilites: {} , logger: nil)
    wait(10, 'No devices, connect device please') { devices.first }
    @speed = capabilites[:speedUp] ? capabilites[:speedUp] : false
    @serial = capabilites[:udid] || devices.first
    @logger = logger
    if @speed == true
      push 'uiautomator/bundle.jar', '/data/local/tmp/'
      push 'uiautomator/uiautomator-stub.jar', '/data/local/tmp/'
      Thread.new do
        exec_command 'uiautomator runtest bundle.jar uiautomator-stub.jar -c com.github.uiautomatorstub.Stub'
      end
      adb 'forward tcp:9009 tcp:9008'
      @client = JSONRPC::Client.new('http://localhost:9009/jsonrpc/0')
    end
  end

  def adb(command)
    wait(10, 'Connection to device has lost') { online? }
    command = "adb -s #{@serial} #{command}"

    @logger.info("[ADB]: #{command}") if @logger

    stdout, stderr, status = Open3.capture3(command)
    if !stderr.empty? && !stderr.include?('Success')
      raise "#{command} failed with message \n #{stderr}"
    end
    stdout
  end

  def online?
    `adb -s #{@serial} get-state`.chomp == 'device'
  end

  def devices
    parts = []
    `adb devices`.lines.each do |line|
      line.strip!
      if !line.empty? && line !~ /^List of devices/
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
    adb "install -r #{path}"
  end

  def uninstall(package_name)
    adb "uninstall #{package_name}"
  end

  def exec_command(command)
    adb "shell exec #{command}"
  end

  def pull(source_path, out_path)
    adb "pull #{source_path} #{out_path}"
  end

  def push(source_path, out_path)
    adb "push #{source_path} #{out_path}"
  end

  def take_screenshot(path)
    exec_command 'screencap -p /sdcard/screenshot.png'
    pull '/sdcard/screenshot.png', path
  end

  def take_screen_source(path)
    unless @speed
      exec_command 'uiautomator dump /sdcard/source.xml'
      pull '/sdcard/source.xml', path
    else
      pull @client.dumpWindowHierarchy(false, 'source.xml'), path
    end
  end

  def launch_package(package, activity)
    unless activity
      exec_command "monkey -p #{package} 1"
    else
      exec_command "am start -n #{package}/#{activity}"
    end
  end

  def current_activity
    out = exec_command 'dumpsys window windows'
    out.lines.grep(/mCurrentFocus/).first[/ (\S*)}/, 1].split('/')
  end
end
