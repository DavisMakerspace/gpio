class GPIOException < RuntimeError; end
class GPIOReadOnlyError < GPIOException; end
class GPIONotExportedError < GPIOException; end
class GPIOPermissionError < GPIOException; end

class GPIO
  GPIO_PATH = "/sys/class/gpio"
  def initialize(id)
    @id = id
    @value_file = nil
  end
  def path(file); "#{GPIO_PATH}/gpio#{@id}/#{file}"; end
  private :path
  def direction_path()
    path("direction")
  end
  def value_path()
    path("value")
  end
  def edge_path()
    path("edge")
  end
  def exported?()
    File.exists?(value_path)
  end
  def export
    File.write("#{GPIO_PATH}/export", @id)
    direction = self.direction
  end
  def unexport()
    File.write("#{GPIO_PATH}/unexport", @id)
    @value_file = nil
  end
  def direction()
    raise GPIONotExportedError.new if !exported?
    File.read(direction_path).strip.to_sym
  end
  def direction=(d)
    raise GPIONotExportedError.new if !exported?
    raise GPIOPermissionError if !File.writable?(direction_path)
    File.write(direction_path, d)
    @value_file = File.new(value_path, 'r') if input?
    @value_file = File.new(value_path, 'w+') if output?
    direction
  end
  def input?()
    direction == :in
  end
  def output?()
    direction == :out
  end
  def edge()
    raise GPIONotExportedError.new if !exported?
    File.read(edge_path).strip.to_sym
  end
  def edge=(e)
    raise GPIONotExportedError.new if !exported?
    raise GPIOPermissionError if !File.writable?(edge_path)
    File.write(edge_path, e)
    edge
  end
  def value()
    raise GPIONotExportedError.new if !exported?
    v = @value_file.read(1)
    @value_file.rewind
    v == "0" ? false : true
  end
  def value=(v)
    raise GPIONotExportedError.new if !exported?
    raise GPIOReadOnlyError.new if input?
    @value_file.write v.to_s
    @value_file.rewind
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
      IO.select(nil, nil, [@value_file], timeout) != nil ? value : nil
    end
  end
  def chown(owner_int, group_int)
    @value_file.chown(owner_int, group_int)
  end
  def chmod(mode_int)
    @value_file.chmod(mode_int)
  end
end
