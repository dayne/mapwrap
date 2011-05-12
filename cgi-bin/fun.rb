#!/usr/bin/env ruby
#
# simple fun.rb CGI script I used for testing behaviors of the 
# URL magic.  Not really useful for mapwrap itself, just useful
# for testing the apache environment it is running in.
#
FUN_PREFIX = "/fun"

require 'cgi'
require 'yaml'
cgi = CGI.new("html4")

# figure out which mapfile to use by parsing the fun:

ru = ENV['REQUEST_URI']

#FUN_PREFIX/(magic!!!)/###
rus = ru.split('/')

fp =  rus[1]
awesome = rus[2]

begin
cgi.out do 
  cgi.html do
    cgi.pre do 
      "\n>>>> cgi.params: ---\n" +
      cgi.params.inspect + 
      "\n>>>> cgi.keys: ---\n" +
      cgi.keys.inspect +
      "\n>>>> FUN TIME: ---\n" +
      "\t#{fp}\n\t#{awesome}" +
      "\n>>>> REQUEST_URI: ---\n" +
      rus.inspect + 
      "\n>>>> ENV: ---\n" +
      ENV.inspect.gsub(",",",\n\t") 
    end
  end
end
rescue error => Exception
  cgi.out do
    cgi.html do
       error.inspect
    end
  end
end
