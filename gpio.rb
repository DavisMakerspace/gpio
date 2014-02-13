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
    File.read(path(:value)).chomp == '1'
  end
  def clear?
    File.read(path(:value)).chomp == '0'
  end
  def set(v = true)
    File.write(path(:value), v ? '1':'0'); self
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
  def poll_once(vio, timeout=nil)
    IO.select(nil, nil, [vio], timeout) != nil ? (vio.rewind;vio.read.chomp=='1') : nil
  end
  private :poll_once
  def poll(timeout:nil, ready:nil)
    vio = File.new path(:value)
    v = poll_once vio
    ready.call v if ready
    if block_given?
      while File.readable? path(:value) do yield(poll_once(vio,timeout)); end
    else
      poll_once(vio, timeout)
    end
  end
end
