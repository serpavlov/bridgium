module Wait
  Error = Class.new(StandardError)

  def self.included(mod)
    mod.extend self
  end

  def wait(duration = 10, message = nil, &block)
    polling_interaval = 0.1 # 100 msec
    start = Time.now

    loop do
      sleep polling_interaval

      result = block.call
      break result if result

      next if Time.now < start + duration

      cleaned_stacktrace = caller.reverse.take_while { |line| line !~ /#{__FILE__}.*#{__method__}/ }.reverse
      raise Error, (message || 'Wait::Error'), cleaned_stacktrace
    end
  end
end
