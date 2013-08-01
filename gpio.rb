class GPIOException < RuntimeError; end
class GPIOSyntaxError < GPIOException; end
class GPIOReadOnlyError < GPIOException; end
class GPIONotExportedError < GPIOException; end

class GPIO
  GPIO_PATH = "/sys/class/gpio"
  DIRECTIONS = [:in, :out, :high, :low]
  EDGES = [:none, :rising, :falling, :both]
  def initialize(id)
    @id = id
    attach
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
  def attach()
    if exported?
      if input?
        @value_file = File.new(value_path, "r")
      else
        @value_file = File.new(value_path, "w")
      end
    else
      @value_file = nil
    end
  end
  def export()
    File.write("#{GPIO_PATH}/export", @id)
    attach
  end
  def unexport()
    File.write("#{GPIO_PATH}/unexport", @id)
    attach
  end
  def direction()
    return File.read(direction_path).strip.to_sym
  end
  def input?()
    return direction == :in
  end
  def output?()
    return direction == :out
  end
  def direction=(d)
    raise GPIOSyntaxError.new if !DIRECTIONS.include?(d)
    File.write(direction_path, d)
    attach()
  end
  def edge()
    return File.read(edge_path).strip.to_sym
  end
  def edge=(e)
    raise GPIOSyntaxError.new if !EDGES.include?(e)
    File.write(edge_path, e)
  end
  def value()
    v = @value_file.read(1)
    @value_file.rewind()
    return v == "0" ? false : true
  end
  def value=(v)
    raise GPIOReadOnlyError.new() if input?
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
    r,w,ready = IO.select(nil, nil, [value_file], timeout)
    return value
  end
  attr_reader :value_file
end

