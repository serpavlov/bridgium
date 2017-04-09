require 'nokogiri'
require 'rexml/document'
require_relative 'element'
require_relative 'adb'

class Session
  def initialize(uid, capabilites)
    @uid = uid
    @adb = Adb.new
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

  def uid
    @uid
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
    when :id         then find_elements_by_xpath("//*[@resource-id='#{locator_value}']")
    when :class_name then find_elements_by_xpath("//*[@class='#{locator_value}']")
    when :text       then find_elements_by_xpath("//*[@content-desc='#{locator_value}']")
    end
  end

  def find_elements_by_xpath(search_string)
    #REXML version
    #view_hierarchy = Nokogiri::XML(source)
    #result = view_hierarchy.xpath(search_string).map { |element| Element.new(element, @adb) }

    #Nokogiri verison
    view_hierarchy = REXML::Document.new(source)
    result = view_hierarchy.get_elements(search_string).map { |element| Element.new(element, @adb) }
  end
end
