class GPIOException < RuntimeError; end
class GPIOSyntaxError < GPIOException; end
class GPIOReadOnlyError < GPIOException; end
class GPIONotExportedError < GPIOException; end

class GPIO
  GPIO_PATH = "/sys/class/gpio"
  DIRECTIONS = [:in, :out, :high, :low]
  EDGES = [:none, :rising, :falling, :both]
  def initialize(id, direction = nil, edge = nil)
    @id = id
    export
    self.direction = direction if direction
    self.edge = edge if edge
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
  def export()
    File.write("#{GPIO_PATH}/export", @id) if !exported?
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
    new_direction = [:high, :low].include?(d) ? :out : d
    File.write(direction_path, d) if direction != new_direction
    export
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
    raise GPIONotExportedError.new if !exported?
    r,w,ready = IO.select(nil, nil, [@value_file], timeout)
    return value
  end
  def chown(owner_int, group_int)
    @value_file.chown(owner_int, group_int)
  end
  def chmod(mode_int)
    @value_file.chmod(mode_int)
  end
end

