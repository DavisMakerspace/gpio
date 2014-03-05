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
    @value = 0
    @direction = :in
    @edge = :none
    @active_low = 0
    @triggers = []
  end
  def add_trigger(t); @triggers.push(t).uniq!; end
  def rm_trigger(t); @triggers.delete(t); end
  def value; @value; end
  def value=(v)
    old_value = @value
    @value = Integer(v)==0?0:1
    @triggers.each{|t|t.fire} if (
      ( old_value != @value && @edge == :both ) ||
      ( old_value == 0 && @value == 1 && @edge == :rising ) ||
      ( old_value == 1 && @value == 0 && @edge == :falling )
    )
    @value
  end
  def direction; @direction; end
  def direction=(d)
    return d if ![:in,:out,:low,:high].include? d
    self.value = d==:high ? 1 : 0 if d!=:in
    @direction = d==:in ? d : :out
  end
  def edge; @edge; end
  def edge=(e); @edge = [:none,:rising,:falling,:both].include?(e) ? e : @edge; end
  def active_low; @active_low; end
  def active_low=(a); @active_low = Integer(a)==0?0:1; end
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
  def low?; @trigger.reset; pin.value == 0; end
  def high?; !low?; end
  def set_low(v=true); pin.value = (v)?0:1; self; end
  def set_high(v=true); set_low(!v); self; end
  [:none, :rising, :falling, :both].each do |edge|
    define_method("set_edge_#{edge}"){ pin.edge = edge; self }
    define_method("edge_#{edge}?"){ pin.edge == edge }
  end
  def active_low?; pin.active_low==1; end
  def set_active_low(v = true); pin.active_low = (v)?1:0; self; end
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
