require_relative 'aapt'
require 'open3'
require 'rexml/document'

class Adb
  
  def adb(command)
    stdout, stderr, status = Open3.capture3("adb "+command)
    if !stderr.empty?
      raise "#{command} failed with message \n #{stderr}" 
    end
    return stdout
  end
    
  def devices
    adb('devices').split("\n")[1..-1]
  end
  
  def restart_adb
    adb 'kill-server'
    adb 'start-server'
  end
  
  def install(path)
    adb "install -r #{path}"
  end
  
  def uninstall(package_name)
    adb "uninstall #{package_name}"
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
    view_hierarchy = REXML::Document.new(source)
  end 
end
