class Element
  Point = Struct.new(:x, :y)

  def initialize(xml_representation)
    @xml_representation = xml_representation
  end

  def click
    `adb shell input tap #{center.x} #{center.y}`
  end

  def long_click
    `adb shell input swipe #{center.x} #{center.y} #{center.x} #{center.y} 800`
  end

  def send_keys(text)
    click
    sleep 2
    `adb shell "input text '#{text}'"`
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
    @coordinates ||= @xml_representation.attributes['bounds'].scan(/\d+/).map(&:to_i)
  end
end

