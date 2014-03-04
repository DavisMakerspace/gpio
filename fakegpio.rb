require 'timeout'
class FakeGPIOTrigger
  MUTEX = Mutex.new
  CV = ConditionVariable.new
  def initialize; @triggered = true; end
  def fire; MUTEX.synchronize{ @triggered=true; CV.broadcast }; end
  def reset; MUTEX.synchronize{ @triggered=false }; end
  def triggered?; @triggered; end
  def self.select(triggers)
    MUTEX.synchronize do
      loop do
        triggered = triggers.select{|t|t.triggered?}
        break triggered if triggered != []
        CV.wait(MUTEX)
      end
    end
  end
end
class FakeGPIOPin
  def initialize
    @value = :low
    @direction = :in
    @edge = :none
    @active_low = false
    @triggers = []
  end
  def add_trigger(t); @triggers.push(t).uniq!; end
  def rm_trigger(t); @triggers.delete(t); end
  def value; @value; end
  def value=(v)
    old_value = @value
    @value = (v==:low ? :low : :high)
    @triggers.each{|t|t.fire} if (
      ( old_value != @value && @edge == :both ) ||
      ( old_value == :low && @value == :high && @edge == :rising ) ||
      ( old_value == :high && @value == :low && @edge == :falling )
    )
    @value
  end
  def direction; @direction; end
  def direction=(d)
    @direction = d if [:in,:out].include? d
    (@direction=:out; @value=d) if [:low,:high].include? d
    @direction
  end
  def edge; @edge; end
  def edge=(e)
    @edge = e if [:none,:rising,:falling,:both].include? e
    @edge
  end
  def active_low; @active_low; end
  def active_low=(a); @active_low = !!a; end
end
class FakeGPIO
  attr_reader :id, :trigger
  PINS = {}
  def initialize(id)
    @id = id
    @trigger = FakeGPIOTrigger.new
  end
  def chmod(_); self; end
  def chown(_,_); self; end
  def pin; PINS[@id]; end
  def exported?; !!pin; end
  def export; PINS[@id]||=FakeGPIOPin.new; pin.add_trigger(@trigger); self; end
  def unexport; PINS.delete(@id); self; end
  def input?; pin.direction == :in; end
  def output?; pin.direction == :out; end
  def set_input; pin.direction = :in; end
  def set_output_low(v=true); pin.direction = (v ? :low : :high); self; end
  def set_output_high(v=true); set_output_low(!v); self; end
  def low?; @trigger.reset; pin.value == :low; end
  def high?; !low?; end
  def set_low(v=true); pin.value = (v ? :low : :high); self; end
  def set_high(v=true); set_low(!v); self; end
  [:none, :rising, :falling, :both].each do |edge|
    define_method("set_edge_#{edge}"){ pin.edge = edge; self }
    define_method("edge_#{edge}?"){ pin.edge == edge }
  end
  def active_low?; pin.active_low; end
  def set_active_low(v = true); pin.active_low = v; self; end
  class << self
    def select(gpios, timeout:nil)
      t2g = Hash[ gpios.map{|g|[g.trigger,g]} ]
      begin
        Timeout.timeout(timeout){ FakeGPIOTrigger.select(t2g.keys).map{|t|t2g[t]} }
      rescue Timeout::Error
        nil
      end
    end
  end
  def select(timeout:nil)
    self.class.select([self],timeout:timeout) ? self : nil
  end
end
