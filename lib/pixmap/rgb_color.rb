class RGBColour

  def initialize(red, green, blue)
    unless red.between?(0,255) and green.between?(0,255) and blue.between?(0,255)
      raise ArgumentError, "invalid RGB parameters: #{[red, green, blue].inspect}"
    end
    @red, @green, @blue = red, green, blue
  end

  attr_reader :red, :green, :blue
  alias_method :r, :red
  alias_method :g, :green
  alias_method :b, :blue

  RED   = RGBColour.new(255,0,0)
  GREEN = RGBColour.new(0,255,0)
  BLUE  = RGBColour.new(0,0,255)
  YELLOW= RGBColour.new(255,255,0)
  BLACK = RGBColour.new(0,0,0)
  WHITE = RGBColour.new(255,255,255)

  def values
    [@red, @green, @blue]
  end

  def luminosity
    Integer(0.2126*@red + 0.7152*@green + 0.0722*@blue)
  end

  def to_grayscale
    l = luminosity
    self.class.new(l, l, l)
  end

  # defines how to compare (and hence, sort)
  def <=>(other)
    self.luminosity <=> other.luminosity
  end

  # the difference between two colours
  def -(a_colour)
    (@red - a_colour.red).abs +
    (@green - a_colour.green).abs +
    (@blue - a_colour.blue).abs
  end
end
