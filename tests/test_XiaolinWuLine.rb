require_relative "../lib/pixmap"

bitmap = Pixmap::Image.new(500, 500)
bitmap.fill(RGBColour::BLUE)
10.step(430, 60) do |a|
  bitmap.draw_line_antialised(Pixel[10, 10], Pixel[490,a], RGBColour::YELLOW)
  bitmap.draw_line_antialised(Pixel[10, 10], Pixel[a,490], RGBColour::YELLOW)
end
bitmap.draw_line_antialised(Pixel[10, 10], Pixel[490,490], RGBColour::YELLOW)
