class GPIO
  GPIO_PATH = "/sys/class/gpio"
  def initialize(id)
    @id = id
  end
  def path(attr='')
    "#{GPIO_PATH}/gpio#{@id}/#{attr}"
  end
  private :path
  def exported?
    File.exists?(path)
  end
  def value_path
    path(:value)
  end
  def export
    File.write("#{GPIO_PATH}/export", @id); self
  end
  def unexport
    File.write("#{GPIO_PATH}/unexport", @id); self
  end
  def input?
    File.read(path(:direction)).chomp == 'in'
  end
  def output?
    File.read(path(:direction)).chomp == 'out'
  end
  def set_input
    File.write(path(:direction), 'in'); self
  end
  def set_output(value = :low)
    File.write(path(:direction), value == :low ? 'low':'high'); self
  end
  def set?
    File.read(value_path).chomp == '1'
  end
  def clear?
    File.read(value_path).chomp == '0'
  end
  def set(v = true)
    File.write(value_path, v ? '1':'0'); self
  end
  def clear
    set false
  end
  def edge
    File.read(path(:edge)).chomp.to_sym
  end
  def set_edge_none
    File.write(path(:edge), 'none'); self
  end
  def set_edge_rising
    File.write(path(:edge), 'rising'); self
  end
  def set_edge_falling
    File.write(path(:edge), 'falling'); self
  end
  def set_edge_both
    File.write(path(:edge), 'both'); self
  end
  def active_low?
    File.read(path(:active_low)).chomp == '1'
  end
  def set_active_low(v = true)
    File.write(path(:active_low), v ? '1':'0'); self
  end
  class << self
    def poll_once(vio2gpio, timeout)
      _,_,ready = IO.select(nil, nil, vio2gpio.keys, timeout)
      ready ? Hash[ready.map{|vio|[vio2gpio[vio],(vio.rewind;vio.read.chomp=='1')]}] : nil
    end
    private :poll_once
    def poll(gpios, timeout:nil, ready:nil)
      vio2gpio = Hash[ gpios.map{|g| [File.new(g.value_path), g]} ]
      v = poll_once(vio2gpio,nil)
      ready.call v if ready
      while !gpios.empty?
        gpio2v = poll_once(vio2gpio, timeout)
        if block_given?
          yield gpio2v
        else
          return gpio2v
        end
        gpios = gpios.select{|g| File.readable? g.value_path}
      end
    end
  end
  def poll(timeout:nil, ready:nil, &block)
    ready_wrapper = ready ? Proc.new{|v| ready.call(v[self])} : nil
    self.class.poll([self], timeout:timeout, ready:ready_wrapper) do |v|
      v = v[self] if v
      if block
        block.call v
      else
        break v
      end
    end
  end
end
