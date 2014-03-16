require 'timeout'
require 'redis'
class FakeGPIO
  attr_reader :id
  def initialize(id)
    @redis = Redis.new
    @id = id
    @edge_count = nil
  end
  def selected?; chkexp; @edge_count!=@redis.get(rkey(:edge_count)); end
  def rkey(name); "gpio:#{@id}:#{name}"; end
  def chmod(_); self; end
  def chown(_,_); self; end
  def exported?; @redis.exists(rkey(:value)); end
  def chkexp; raise "Not exported" if !exported?; end
  def export; @redis.mset(rkey(:value),"\0",rkey(:direction),:in,rkey(:edge),:none,rkey(:active_low),"\0",rkey(:edge_count),'0'); self; end
  def unexport; chkexp; @redis.del(rkey(:value),rkey(:direction),rkey(:edge),rkey(:active_low),rkey(:edge_count)); self; end
  def input?; chkexp; @redis.get(rkey(:direction)).to_sym==:in; end
  def output?; chkexp; @redis.get(rkey(:direction)).to_sym==:out; end
  def set_input; chkexp; @redis.set(rkey(:direction),:in); self; end
  def set_output_low(v=true); chkexp; @redis.set(rkey(:direction),:out); self.set_low(v); end
  def set_output_high(v=true); set_output_low(!v); end
  def low?; chkexp; @edge_count=@redis.get(rkey(:edge_count)); @redis.getbit(rkey(:value),0)==0; end
  def high?; !low?; end
  def set_low(v=true); chkexp
    new = v ? 0 : 1
    old = @redis.setbit(rkey(:value),0,new)
    (@redis.incr(rkey(:edge_count)); @redis.publish('gpio:edge',@id)) if
      ( old != new && self.edge_both? ) ||
      ( old == 0 && new == 1 && self.edge_rising? ) ||
      ( old == 1 && new == 0 && self.edge_falling? )
    self
  end
  def set_high(v=true); set_low(!v); end
  [:none, :rising, :falling, :both].each do |edge|
    define_method("edge_#{edge}?"){ chkexp; @redis.get(rkey(:edge)).to_sym == edge }
    define_method("set_edge_#{edge}"){ chkexp; @redis.set(rkey(:edge),edge); self }
  end
  def active_low?; chkexp; @redis.getbit(rkey(:active_low),0)==1; end
  def set_active_low(v=true); chkexp; @redis.setbit(rkey(:active_low),(v)?1:0); self; end
  class << self
    def select(gpios, timeout:nil)
      redis = Redis.new
      begin
        selected = gpios.select{|g|g.selected?}
        return selected if selected != []
        Timeout.timeout(timeout){redis.subscribe('gpio:edge'){|s|s.message{
          selected = gpios.select{|g|g.selected?}
          redis.unsubscribe if selected
        }}}
        selected
      rescue Timeout::Error
        nil
      end
    end
  end
  def select(timeout:nil)
    self.class.select([self],timeout:timeout) ? self : nil
  end
end
