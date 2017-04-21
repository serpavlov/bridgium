require 'logger'
require 'nokogiri'
require 'rexml/document'

require_relative 'element'
require_relative 'adb'

class Session
  def initialize(uid, capabilites, logger)
    @uid = uid
    @capabilites = capabilites
    @logger = logger || Logger.new(STDOUT)
    @adb = Adb.new(capabilites['udid'])
    if @capabilites['app']
      if @capabilites['fullReset'] == true
        @logger.info 'Reinstalling app'

        @adb.reinstall(@capabilites['app'])
      end

      if @capabilites['fullReset'] == false || @capabilites['fullReset'] == nil
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
        @adb.launch_package_with_activity(@capabilites['appPackage'], @capabilites['appActivity'])
      else
        @logger.info 'You have not add appActivity to capabilites, OK'

        @adb.launch_package(@capabilites['appPackage'])
      end
    else
      @logger.info 'You have not add appPackage to capabilites, OK'
    end
  end

  def source
    @adb.take_screen_source
  end

  def elements(req)
    find_elements(req)
  end

  def element(req)
    elements(req).first
  end

  def take_screenshot
    @adb.take_screenshot('temp/screenshot.png')
  end

  def uid
    @uid
  end

  def back
    @adb.exec_command "input keyevent KEYCODE_BACK"
  end

  def caps
    @capabilites
  end

  def execute(command)
    if command['script'] == 'adb'
      case command['args'].first
      when "get_current_activity"         then result = @adb.get_current_activity
      when "pull"                         then result = @adb.pull(command['args'][1], command['args'][2])
      when "launch_package"               then result = @adb.launch_package(command['args'][1])
      when "launch_package_with_activity" then result = @adb.launch_package_with_activity(command['args'][1], command['args'][2])
      end
    end
    result
  end

  private

  def find_elements(locator)
    locator_type = locator.first.first
    locator_value = locator.first.last

    case locator_type
    when :xpath      then find_elements_by_xpath(locator_value)
    when :id         then find_elements_by_xpath("//*[contains(@resource-id,'#{locator_value}')]")
    when :class_name then find_elements_by_xpath("//*[@class='#{locator_value}']")
    when :text       then find_elements_by_xpath("//*[@content-desc='#{locator_value}']")
    end
  end

  def find_elements_by_xpath(search_string)
    #REXML version
    #view_hierarchy = REXML::Document.new(source)
    #result = view_hierarchy.get_elements(search_string).map { |element| Element.new(element, @adb) }

    #Nokogiri verison
    view_hierarchy = Nokogiri::XML(source)
    result = view_hierarchy.xpath(search_string).map { |element| Element.new(element, @adb) }
  end
end
