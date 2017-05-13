require_relative 'searcher'

class Element
  include Searcher
  Point = Struct.new(:x, :y)

  def initialize(xml_representation, adb)
    @xml_representation = xml_representation
    @adb = adb
  end

  def element(req)
    elements(req).first
  end

  def elements(req)
    find_elements(@xml_representation, req)
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

  def attribute(attr)
    @xml_representation.get_attribute attr
  end

  def send_keys(text)
    click
    @adb.exec_command "input text '#{text}'"
  end

  def text
    @xml_representation.get_attribute('text')
  end

  def enabled?
    @xml_representation.get_attribute('enabled') == 'true'
  end

  def displayed?
    @xml_representation.get_attribute('displayed') == 'true'
  end

  def selected?
    @xml_representation.get_attribute('selected') == 'true'
  end

  def location
    { x: top_left.x, y: top_left.y }
  end

  def size
    { width: width, height: height }
  end

  private

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

  def coordinates
    @xml_representation.get_attribute('bounds').scan(/\d+/).map(&:to_i)
  end
end

