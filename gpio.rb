class GPIO
  attr_reader :id
  GPIO_PATH = "/sys/class/gpio"
  def initialize(id)
    @id = id
  end
  [:value, :direction, :edge, :active_low].each do |attr|
    define_method("#{attr}_path"){ "#{GPIO_PATH}/gpio#{id}/#{attr}" }
  end
  def to_io; @io||=File.new(value_path); end
  def exported?; File.exists?(value_path); end
  def export; File.write("#{GPIO_PATH}/export", id); self; end
  def unexport; File.write("#{GPIO_PATH}/unexport", id); self; end
  def input?; File.read(direction_path).chomp == 'in'; end
  def output?; File.read(direction_path).chomp == 'out'; end
  def set_input; File.write(direction_path, 'in'); self; end
  def set_output_low(v=true); File.write(direction_path, v ? 'low':'high'); self; end
  def set_output_high(v=true); set_output_low(!v); self; end
  def low?; to_io.rewind; to_io.read.chomp == '0'; end
  def high?; !low?; end
  def set_low(v=true); File.write(value_path, v ? '0':'1'); self; end
  def set_high(v=true); set_low(!v); self; end
  [:none, :rising, :falling, :both].each do |edge|
    define_method("set_edge_#{edge}"){ File.write(edge_path, edge); self }
    define_method("edge_#{edge}?"){ File.read(edge_path).chomp.to_sym == edge }
  end
  def active_low?; File.read(active_low_path).chomp == '1'; end
  def set_active_low(v = true); File.write(active_low_path, v ? '1':'0'); self; end
  class << self
    def select(gpios, timeout:nil)
      _,_,r = IO.select(nil,nil,gpios,timeout); r
    end
  end
  def select(timeout:nil)
    self.class.select([self],timeout:timeout) ? self : nil
  end
end
