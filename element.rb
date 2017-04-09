class Element
  Point = Struct.new(:x, :y)

  def initialize(xml_representation, adb)
    @xml_representation = xml_representation
    @adb = adb
  end

  def element(req)
    elements(req).first
  end

  def elements(req)
    find_elements(req)
  end

  def click
    @adb.exec_command "input tap #{center.x} #{center.y}"
  end

  def clear
    @adb.exec_command 'input keyevent KEYCODE_MOVE_END'
    text.size.times do
      @adb.exec_command 'input keyevent KEYCODE_DEL'
    end
  end

  def long_click
    @adb.exec_command "input swipe #{center.x} #{center.y} #{center.x} #{center.y} 800"
  end

  def send_keys(text)
    click
    sleep 2
    @adb.exec_command "input text '#{text}'"
  end

  def text
    @xml_representation.attributes['text']
  end

  def checked?
    @xml_representation.attributes['checked'] == 'true'
  end

  def content_desc
    @xml_representation.attributes['content-desc']
  end

  def top_left
    Point.new(coordinates[0], coordinates[1])
  end

  def lower_right
    Point.new(coordinates[2], coordinates[3])
  end

  def width
    lower_right.x - top_left.x
  end

  def height
    lower_right.y - top_left.y
  end

  def center
    Point.new(top_left.x + width / 2, top_left.y + height / 2)
  end

  private

  def coordinates
    @xml_representation.get_attribute('bounds').scan(/\d+/).map(&:to_i)
  end

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
    view_hierarchy = @xml_representation
    #REXML version
    #result = view_hierarchy.get_elements(view_hierarchy.xpath + search_string).map { |element| Element.new(element, @adb) }

    #Nokogiri verison
    result = view_hierarchy.xpath(view_hierarchy.path + search_string).map { |element| Element.new(element, @adb) }
  end
end

