require_relative "../lib/pixmap"

# create an image: a green cross on a blue background
colour_bitmap = Pixmap::Image.new(20, 30)
colour_bitmap.fill(RGBColour::BLUE)
colour_bitmap.height.times {|y| [9,10,11].each {|x| colour_bitmap[x,y]=RGBColour::GREEN}}
colour_bitmap.width.times  {|x| [14,15,16].each {|y| colour_bitmap[x,y]=RGBColour::GREEN}}
colour_bitmap.save('testcross.ppm')

# then, convert to grayscale
Pixmap.open('testcross.ppm').to_grayscale!.save('testgray.ppm')


image = Pixmap.open('testcross.ppm')
image.save_as_jpeg('testcross.jpg')
