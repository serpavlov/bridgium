require 'nokogiri'
require 'rexml/document'

require_relative 'element'
require_relative 'adb'

class Session
  def initialize(uid, capabilites)
    @capabilites = capabilites
    @uid = uid
    @adb = Adb.new(capabilites['udid'])
    if @capabilites['app']
      if @capabilites['fullReset'] == 'true'
        @adb.reinstall(@capabilites['app']
      end
      if @capabilites['fullReset'] == 'false' || @capabilites['fullReset'] == nil
        @adb.install(@capabilites['app']
      end
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
