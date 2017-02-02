#!/usr/bin/env ruby
#
# A simple widget that serves up an "deny" image based on a wms request.
#
require 'cgi'
require 'mixlib/shellout'

##
# locate items in CGI params
def pfind(name, location)
  result = nil
  [name, name.upcase, name.downcase].each do |n|
    next if result
    result = location[n].first if location[n] && location[n].size > 0
  end
  STDERR.puts "found #{result} for #{name}" if $test

  result
end

# invoke CGI
cgi = CGI.new('html4')

# RuntimeError with the message to be displayed to the user if error
begin
  tile = File.dirname(__FILE__) + '/deny.png'

  # default to png.
  image_magick_format = 'png'
  mime_format = 'image/png'

  # check to see if request is for a jpeg
  format = pfind('format', cgi.params)
  if format && format[0].downcase.include?('jpeg')
    image_magick_format = 'jpg'
    mime_format = 'image/jpeg'
  end

  width = pfind('width', cgi.params).to_i
  height = pfind('height', cgi.params).to_i

  # set some sane widths and heights defaults.
  width = 128 if !width || width <= 10
  height = 128 if !height || height <= 10

  STDERR.puts("convert -size #{width}x#{height} tile:#{tile} -fill transparent #{image_magick_format}:-")
  command = Mixlib::ShellOut.new("convert -size #{width}x#{height} tile:#{tile} -fill white #{image_magick_format}:-")

  cgi.out(mime_format) { command.run_command; command.stdout }

rescue  RuntimeError => problem
  cgi.out do
    cgi.html do
      'An Error Occurred: ' + problem.to_s
    end
  end
end
