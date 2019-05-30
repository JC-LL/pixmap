require_relative "rgb_color"

module Pixmap

  def self.open(filename)
    bitmap = nil
    File.open(filename, 'r') do |f|
      header = [f.gets.chomp, f.gets.chomp, f.gets.chomp]
      width, height = header[1].split.map {|n| n.to_i }
      if header[0] != 'P6' or header[2] != '255' or width < 1 or height < 1
        raise StandardError, "file '#{filename}' does not start with the expected header"
      end
      f.binmode
      bitmap = Image.new(width, height)
      height.times do |y|
        width.times do |x|
          # read 3 bytes
          red, green, blue = f.read(3).unpack('C3')
          bitmap[x,y] = RGBColour.new(red, green, blue)
        end
      end
    end
    bitmap
  end

  class Image

    def initialize(width=nil, height=nil)
      @width = width
      @height = height
      @data = fill(RGBColour::WHITE)
    end

    attr_reader :width, :height

    def fill(colour)
      @data = Array.new(@width) {Array.new(@height, colour)}
    end

    def validate_pixel(x,y)
      unless x.between?(0, @width-1) and y.between?(0, @height-1)
        raise ArgumentError, "requested pixel (#{x}, #{y}) is outside dimensions of this bitmap"
      end
    end

    def [](x,y)
      validate_pixel(x,y)
      @data[x][y]
    end
    alias_method :get_pixel, :[]

    def []=(x,y,colour)
      validate_pixel(x,y)
      @data[x][y] = colour
    end
    alias_method :set_pixel, :[]=

    def to_grayscale
      gray = self.class.new(@width, @height)
      @width.times do |x|
        @height.times do |y|
          gray[x,y] = self[x,y].to_grayscale
        end
      end
      gray
    end

    def to_grayscale!
      @width.times do |x|
        @height.times do |y|
          self[x,y] = self[x,y].to_grayscale
        end
      end
      self
    end

    def save(filename)
      File.open(filename, 'w') do |f|
        f.puts "P6", "#{@width} #{@height}", "255"
        f.binmode
        @height.times do |y|
          @width.times do |x|
            f.print @data[x][y].values.pack('C3')
          end
        end
      end
    end

    alias_method :write, :save

    PIXMAP_FORMATS = ["P3", "P6"]   # implemented output formats
    PIXMAP_BINARY_FORMATS = ["P6"]  # implemented output formats which are binary

    def write_ppm(ios, format="P6")
      if not PIXMAP_FORMATS.include?(format)
        raise NotImplementedError, "pixmap format #{format} has not been implemented"
      end
      ios.puts format, "#{@width} #{@height}", "255"
      ios.binmode if PIXMAP_BINARY_FORMATS.include?(format)
      @height.times do |y|
        @width.times do |x|
          case format
          when "P3" then ios.print @data[x][y].values.join(" "),"\n"
          when "P6" then ios.print @data[x][y].values.pack('C3')
          end
        end
      end
    end

    def save(filename, opts={:format=>"P6"})
      File.open(filename, 'w') do |f|
        write_ppm(f, opts[:format])
      end
    end

    def print(opts={:format=>"P6"})
      write_ppm($stdout, opts[:format])
    end

    def save_as_jpeg(filename, quality=75)
      pipe = IO.popen("convert ppm:- -quality #{quality} jpg:#{filename}", 'w')
      write_ppm(pipe)
      pipe.close
    end

    require_relative "progress_bar"
    def convolute(kernel)
      newimg = Image.new(@width, @height)
      pb = ProgressBar.new(@width) if $DEBUG
      @width.times do |x|
        @height.times do |y|
          apply_kernel(x, y, kernel, newimg)
        end
        pb.update(x) if $DEBUG
      end
      pb.close if $DEBUG
      newimg
    end

      # Applies a convolution kernel to produce a single pixel in the destination
    def apply_kernel(x, y, kernel, newimg)
      x0 = x==0 ? 0 : x-1
      y0 = y==0 ? 0 : y-1
      x1 = x
      y1 = y
      x2 = x+1==@width  ? x : x+1
      y2 = y+1==@height ? y : y+1

      r = g = b = 0.0
      [x0, x1, x2].zip(kernel).each do |xx, kcol|
        [y0, y1, y2].zip(kcol).each do |yy, k|
          r += k * self[xx,yy].r
          g += k * self[xx,yy].g
          b += k * self[xx,yy].b
        end
      end
      newimg[x,y] = RGBColour.new(luma(r), luma(g), luma(b))
    end

    # Function for clamping values to those that we can use with colors
    def luma(value)
      if value < 0
        0
      elsif value > 255
        255
      else
        value
      end
    end

    def histogram
      histogram = Hash.new(0)
      @height.times do |y|
        @width.times do |x|
          histogram[self[x,y].luminosity] += 1
        end
      end
      histogram
    end

    def to_blackandwhite
      hist = histogram

      # find the median luminosity
      median = nil
      sum = 0
      hist.keys.sort.each do |lum|
        sum += hist[lum]
        if sum > @height * @width / 2
          median = lum
          break
        end
      end

      # create the black and white image
      bw = Image.new(@width, @height)
      @height.times do |y|
        @width.times do |x|
          bw[x,y] = self[x,y].luminosity < median ? RGBColour::BLACK : RGBColour::WHITE
        end
      end
      bw
    end

    def save_as_blackandwhite(filename)
      to_blackandwhite.save(filename)
    end

    def median_filter(radius=3)
      radius += 1 if radius.even?
      filtered = Image.new(@width, @height)
      pb = ProgressBar.new(@height) if $DEBUG
      @height.times do |y|
        @width.times do |x|
          window = []
          (x - radius).upto(x + radius).each do |win_x|
            (y - radius).upto(y + radius).each do |win_y|
              win_x = 0 if win_x < 0
              win_y = 0 if win_y < 0
              win_x = @width-1 if win_x >= @width
              win_y = @height-1 if win_y >= @height
              window << self[win_x, win_y]
            end
          end
          # median
          filtered[x, y] = window.sort[window.length / 2]
        end
        pb.update(y) if $DEBUG
      end
      pb.close if $DEBUG
      filtered
    end

    def draw_line_antialised(p1, p2, colour)
      x1, y1 = p1.x, p1.y
      x2, y2 = p2.x, p2.y

      steep = (y2 - y1).abs > (x2 - x1).abs
      if steep
        x1, y1 = y1, x1
        x2, y2 = y2, x2
      end
      if x1 > x2
        x1, x2 = x2, x1
        y1, y2 = y2, y1
      end
      deltax = x2 - x1
      deltay = (y2 - y1).abs
      gradient = 1.0 * deltay / deltax

      # handle the first endpoint
      xend = x1.round
      yend = y1 + gradient * (xend - x1)
      xgap = rfpart(x1 + 0.5)
      xpxl1 = xend
      ypxl1 = ipart(yend)
      put_colour(xpxl1, ypxl1, colour, steep, rfpart(yend)*xgap)
      put_colour(xpxl1, ypxl1 + 1, colour, steep, fpart(yend)*xgap)
      itery = yend + gradient

      # handle the second endpoint
      xend = x2.round
      yend = y2 + gradient * (xend - x2)
      xgap = rfpart(x2 + 0.5)
      xpxl2 = xend
      ypxl2 = ipart(yend)
      put_colour(xpxl2, ypxl2, colour, steep, rfpart(yend)*xgap)
      put_colour(xpxl2, ypxl2 + 1, colour, steep, fpart(yend)*xgap)

      # in between
      (xpxl1 + 1).upto(xpxl2 - 1).each do |x|
        put_colour(x, ipart(itery), colour, steep, rfpart(itery))
        put_colour(x, ipart(itery) + 1, colour, steep, fpart(itery))
        itery = itery + gradient
      end
    end

    def put_colour(x, y, colour, steep, c)
      x, y = y, x if steep
      self[x, y] = anti_alias(colour, self[x, y], c)
    end

    def anti_alias(new, old, ratio)
      blended = new.values.zip(old.values).map {|n, o| (n*ratio + o*(1.0 - ratio)).round}
      RGBColour.new(*blended)
    end

    # the difference between two images
    def -(a_pixmap)
      if @width != a_pixmap.width or @height != a_pixmap.height
        raise ArgumentError, "can't compare images with different sizes"
      end
      sum = 0
      each_pixel {|x,y| sum += self[x,y] - a_pixmap[x,y]}
      Float(sum) / (@width * @height * 255 * 3)
    end

    #Bresenham
    def draw_line(p1, p2, colour)
      validate_pixel(p1.x, p2.y)
      validate_pixel(p2.x, p2.y)

      x1, y1 = p1.x, p1.y
      x2, y2 = p2.x, p2.y

      steep = (y2 - y1).abs > (x2 - x1).abs

      if steep
        x1, y1 = y1, x1
        x2, y2 = y2, x2
      end

      if x1 > x2
        x1, x2 = x2, x1
        y1, y2 = y2, y1
      end

      deltax = x2 - x1
      deltay = (y2 - y1).abs
      error = deltax / 2
      ystep = y1 < y2 ? 1 : -1

      y = y1
      x1.upto(x2) do |x|
        pixel = steep ? [y,x] : [x,y]
        self[*pixel] = colour
        error -= deltay
        if error < 0
          y += ystep
          error += deltax
        end
      end
    end

    def draw_bezier_curve(points, colour)
      # ensure the points are increasing along the x-axis
      points = points.sort_by {|p| [p.x, p.y]}
      xmin = points[0].x
      xmax = points[-1].x
      increment = 2
      prev = points[0]
      ((xmin + increment) .. xmax).step(increment) do |x|
        t = 1.0 * (x - xmin) / (xmax - xmin)
        p = Pixel[x, bezier(t, points).round]
        draw_line(prev, p, colour)
        prev = p
      end
    end

    def draw_circle(pixel, radius, colour)
      validate_pixel(pixel.x, pixel.y)

      self[pixel.x, pixel.y + radius] = colour
      self[pixel.x, pixel.y - radius] = colour
      self[pixel.x + radius, pixel.y] = colour
      self[pixel.x - radius, pixel.y] = colour

      f = 1 - radius
      ddF_x = 1
      ddF_y = -2 * radius
      x = 0
      y = radius
      while x < y
        if f >= 0
          y -= 1
          ddF_y += 2
          f += ddF_y
        end
        x += 1
        ddF_x += 2
        f += ddF_x
        self[pixel.x + x, pixel.y + y] = colour
        self[pixel.x + x, pixel.y - y] = colour
        self[pixel.x - x, pixel.y + y] = colour
        self[pixel.x - x, pixel.y - y] = colour
        self[pixel.x + y, pixel.y + x] = colour
        self[pixel.x + y, pixel.y - x] = colour
        self[pixel.x - y, pixel.y + x] = colour
        self[pixel.x - y, pixel.y - x] = colour
      end
    end
  end
end

# helpers
Pixel = Struct.new(:x, :y)

# the generalized n-degree Bezier summation
def bezier(t, points)
  n = points.length - 1
  points.each_with_index.inject(0.0) do |sum, (point, i)|
    sum += n.choose(i) * (1-t)**(n - i) * t**i * point.y
  end
end

class Integer
  def choose(k)
    self.factorial / (k.factorial * (self - k).factorial)
  end
  def factorial
    (2 .. self).reduce(1, :*)
  end
end

def ipart(n); n.truncate; end
def fpart(n); n - ipart(n); end
def rfpart(n); 1.0 - fpart(n); end
