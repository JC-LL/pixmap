require_relative "../lib/pixmap"

# Demonstration code using the teapot image from Tk's widget demo
$DEBUG=true

teapot = Pixmap::open('teapot.ppm')
{ :emboss => [[-2.0, -1.0, 0.0],  [-1.0, 1.0, 1.0],  [0.0, 1.0, 2.0]],
  :sharpen=> [[-1.0, -1.0, -1.0], [-1.0, 9.0, -1.0], [-1.0, -1.0, -1.0]],
  :blur   => [[0.1111,0.1111,0.1111],[0.1111,0.1111,0.1111],[0.1111,0.1111,0.1111]],
}.each do |label, kernel|
  savefile = 'teapot_' + label.to_s + '.ppm'
  teapot.convolute(kernel).save(savefile)
end
