require 'logger'
require 'nokogiri'

require_relative 'element'
require_relative 'adb'
require_relative 'searcher'

class Session
  include Searcher

  def initialize(capabilites, logger)
    @capabilites = capabilites
    @logger = logger || Logger.new(STDOUT)
    device_udid = capabilites ? capabilites['udid'] : nil
    @adb = Adb.new(device_udid, @logger)
    if @capabilites
      if @capabilites['app']
        if @capabilites['fullReset']
          @logger.info 'Reinstalling app'

          @adb.reinstall(@capabilites['app'])
        else
          @logger.info 'Installing app'

          @adb.install(@capabilites['app'])
        end

        @capabilites['appPackage'] = Aapt.package_name(@capabilites['app']) unless @capabilites['appPackage']
      else
        @logger.info 'You have not add app to capabilites, OK'
      end

      if @capabilites['appPackage']
        @logger.info 'Launching the app'

        if @capabilites['appActivity']
          @adb.launch_package_with_activity(@capabilites['appPackage'],
                                            @capabilites['appActivity'])
        else
          @logger.info 'You have not add appActivity to capabilites, OK'

          @adb.launch_package(@capabilites['appPackage'])
        end
      else
        @logger.info 'You have not add appPackage to capabilites, OK'
      end
    end
  end

  def source
    @adb.take_screen_source
  end

  def elements(req)
    view_hierarchy = Nokogiri::XML(source)
    find_elements(view_hierarchy, req)
  end

  def element(req)
    elements(req).first
  end

  def take_screenshot
    @adb.take_screenshot('temp/screenshot.png')
  end

  def back
    @adb.exec_command 'input keyevent KEYCODE_BACK'
  end

  def caps
    @capabilites
  end

  def execute(command)
    if command['script'] == 'adb'
      args = command['args']
      case args.first
      when 'get_current_activity'
        result = @adb.current_activity
      when 'pull'
        result = @adb.pull(args[1], args[2])
      when 'launch_package'
        result = @adb.launch_package(args[1])
      when 'launch_package_with_activity'
        result = @adb.launch_package_with_activity(args[1], args[2])
      end
    end
    result
  end
end

