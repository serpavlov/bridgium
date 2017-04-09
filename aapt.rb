module Aapt
  def package_name(path)
    `aapt dump badging #{APK_FILENAME}`.lines.grep(/package/).first[/name='(\S*)'/, 1]
  end
end
