require_relative "../lib/pixmap"

bitmap = Pixmap::Image.new(400, 400)
points = [
  Pixel[40,100], Pixel[100,350], Pixel[150,50],
  Pixel[150,150], Pixel[350,250], Pixel[250,250]
]
points.each {|p| bitmap.draw_circle(p, 3, RGBColour::RED)}
bitmap.draw_bezier_curve(points, RGBColour::BLUE)

bitmap.save("bezier.ppm")
