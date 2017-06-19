module Searcher
  def self.included(mod)
    mod.extend self
  end

  def find_els(view_hierarchy, locator)
    locator_type = locator.first.first
    locator_value = locator.first.last

    case locator_type
    when :xpath
      search_string = locator_value
    when :id
      search_string = "//*[contains(@resource-id,'#{locator_value}')]"
    when :class_name
      search_string = "//*[@class='#{locator_value}']"
    when :link_text
      search_string = "//*[@text='#{locator_value}']"
    when :accessibility_id
      search_string = "//*[@content-desc='#{locator_value}']"
    else
      raise KeyError, 'Can find only by xpath, id, class name and text'
    end
    path = view_hierarchy.path
    search_string = path + search_string if path != '/'
    find_els_by_xpath(view_hierarchy, search_string)
  end

  def find_els_by_xpath(view_hierarchy, search_string)
    view_hierarchy.xpath(search_string).map do |element|
      Element.new(element, @adb)
    end
  end
end
