module Utils
  class << self
    def deep_copy(obj)
      Marshal.load(Marshal.dump(obj))
    end
  end
end
