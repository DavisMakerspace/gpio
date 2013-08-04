class GPIOException < RuntimeError; end
class GPIOSyntaxError < GPIOException; end
class GPIOReadOnlyError < GPIOException; end
class GPIONotExportedError < GPIOException; end
class GPIOPermissionError < GPIOException; end

class GPIO
  GPIO_PATH = "/sys/class/gpio"
  DIRECTIONS = [:in, :out, :high, :low]
  EDGES = [:none, :rising, :falling, :both]
  def initialize(id, direction = nil, edge = nil)
    @id = id
    export(direction, edge)
  end
  def path(file)
    return "#{GPIO_PATH}/gpio#{@id}/#{file}"
  end
  def direction_path()
    return path("direction")
  end
  def value_path()
    return path("value")
  end
  def edge_path()
    return path("edge")
  end
  def exported?()
    return File.exists?(value_path)
  end
  def export(direction = nil, edge = nil)
    if !exported?
      File.write("#{GPIO_PATH}/export", @id)
      self.direction = direction if direction
      self.edge = edge if edge
    end
    if input? && (!@value_file || @value_file_mode == "w")
      @value_file_mode = "r"
      @value_file = File.new(value_path, @value_file_mode)
    elsif output? && (!@value_file || @value_file_mode != "w")
      @value_file_mode = "w"
      @value_file = File.new(value_path, @value_file_mode)
    end
  end
  def unexport()
    File.write("#{GPIO_PATH}/unexport", @id) if exported?
    @value_file = nil
  end
  def direction()
    raise GPIONotExportedError.new if !exported?
    return File.read(direction_path).strip.to_sym
  end
  def direction=(d)
    raise GPIOSyntaxError.new if !DIRECTIONS.include?(d)
    raise GPIONotExportedError.new if !exported?
    raise GPIOPermissionError if !File.writable?(direction_path)
    File.write(direction_path, d)
  end
  def input?()
    return direction == :in
  end
  def output?()
    return direction == :out
  end
  def edge()
    raise GPIONotExportedError.new if !exported?
    return File.read(edge_path).strip.to_sym
  end
  def edge=(e)
    raise GPIOSyntaxError.new if !EDGES.include?(e)
    raise GPIONotExportedError.new if !exported?
    raise GPIOPermissionError if !File.writable?(edge_path)
    File.write(edge_path, e) if edge != e
  end
  def value()
    raise GPIONotExportedError.new if !exported?
    v = @value_file.read(1)
    @value_file.rewind()
    return v == "0" ? false : true
  end
  def value=(v)
    raise GPIONotExportedError.new if !exported?
    raise GPIOReadOnlyError.new if input?
    @value_file.write(v)
    @value_file.rewind()
  end
  def set()
    self.value = "1"
  end
  def clear()
    self.value = "0"
  end
  def poll(timeout = nil)
    if block_given?
      while @value_file
        yield self.poll timeout
      end
    else
      raise GPIONotExportedError.new if !exported?
      return IO.select(nil, nil, [@value_file], timeout) != nil ? value : nil
    end
  end
  def chown(owner_int, group_int)
    @value_file.chown(owner_int, group_int)
  end
  def chmod(mode_int)
    @value_file.chmod(mode_int)
  end
end

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
        ready[2].each { |io| yield io2gpio[io] }
      else
        yield nil
      end
    end
  end
  attr_accessor :gpios, :timeout
end
