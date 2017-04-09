module Aapt
  def self.package_name(path)
    `aapt dump badging #{path}`.lines.grep(/package/).first[/name='(\S*)'/, 1]
  end
end
