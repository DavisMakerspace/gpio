class GPIOPoller
  def initialize(gpios = [], timeout = nil)
    @gpios = gpios
    @timeout = timeout
  end
  def run()
    while @gpios.size > 0
      io2gpio = {}
      gpios.each { |g| io2gpio[g.instance_variable_get(:@value_file)] = g }
      ready = IO.select(nil, nil, io2gpio.keys, @timeout)
      if ready
        ready[2].each { |io| yield io2gpio[io], io2gpio[io].value }
      else
        yield :timeout
      end
    end
  end
  attr_accessor :gpios, :timeout
end
