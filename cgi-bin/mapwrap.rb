#!/usr/bin/env ruby
=begin

A MapServer CGI wrapper that simplifies the URLs to your WMS services.

http://github.com/dayne/mapwrap

* defaults SERVICE to WMS
* defaults REQUEST to GetCapabilities
* allows for projection optimized mapfiles
* accepts both POST and GET requests


basic mapper scheme..

1) loop though configs: 
  compare each item, maching prefix with "url", if it matchs, then use that item for 
2) if nothing matches, check "default", compare with "prefix" if it matches use that item
   if so, then attempt to match with the items in "map"
3) if nothing matches, then generate an error.

=end

CONFIG_FILE = File.dirname(__FILE__) + "/../apps/map_wrap/conf.yml"

##
# Looks for request in config
def find_item ( config, request ) 
	config.keys.each do |item|
		return config[item] if ( request == config[item]["url"])
	end
	nil
end

def pfind( name, location )
	result = false
	[name, name.upcase, name.downcase].each do |n|
		next if result
		result = location[n] if location[n] and location[n].size > 0 
	end
	STDERR.puts "found #{result} for #{name}" if $test
	result
end


##
#  attempt to load config ..
unless File.exists?(CONFIG_FILE)
# bad path to config, lets see if we can find it in ../conf.yml
  poke = File.join(File.dirname(__FILE__),'..','conf.yml')
  CONFIG_FILE = poke if File.exists?( poke )
end

require 'cgi'
require 'yaml'
cgi = CGI.new("html4")
conf = YAML.load_file(CONFIG_FILE)

# figure out which mapfile to use by parsing the fun:
magic = ENV['REQUEST_URI'].split('?')[0].split('/') if ENV['REQUEST_URI']

empty = magic[0]
fun = magic[1]
map = magic[2]

map = fun if (!map || map == "")

#First look in "configs", and see if the url has a direct mapping..
conf_item = find_item(conf["configs"], fun) if (conf["configs"] && conf["configs"].keys.length > 0)

if (conf_item)
	#for each item we need a "mapserv" and a "envsh" - if these don't exist, copy them from the default set.
	["mapserv", "envsh"].each { |conf_key_set| conf_item[conf_key_set]=conf["defaults"][conf_key_set] if (!conf_item[conf_key_set]) }
	conf = conf_item
else
	#no direct url mapping, use defaults.
	conf = conf["defaults"]
end


begin
	##
	# In a catch block - if errors accor rase an RuntimeError with the message to be displayed to the user.
	
	#verfiy that the mapserv path is set..
	if conf['mapserv']
	  mapserv=conf['mapserv']
	else
	  mapserv='mapserv' # rely on environment path to provide mapserv
	end
	
	case magic[3]
	  when 'test' then 
	    $test = true
	  else
	    # no special sauce asked for, none given
	end
	
	
	if fun != conf["prefix"]
	  # TODO error out here as the script has been run badly
	  raise RuntimeError.new( "<b>MapWrap Error:</b>  <br />" + 
	      "<tt>MAP_PREFIX=#{conf["prefix"]}</tt> but got <tt>#{fun}</tt> instead." )
	end
	
	# A little more verbose than is require, but x||y||z logic does not appear to work..
	srs = cgi['srs']
	srs = cgi['SRS'] if (srs == nil || srs == "")
	srs = cgi['crs'] if (srs == nil || srs == "")
	srs = cgi['CRS'] if (srs == nil || srs == "")
	
	srs = srs.join() if (srs.class == Array)
	proj = nil
	proj = srs.split(":").last.to_i if (srs)
	
	
	# if proj is in the maps thing use it or just use default
	
	if map and conf['maps'][map]
	  mapfile = conf['maps'][map]
	  if mapfile.class == Hash
		if mapfile[proj]
			mapfile = mapfile[proj]
		else
			mapfile = mapfile['default']
		end
	  end
	end
	
	STDERR.puts("Mapwrap: srs is #{cgi['CRS']}")
	STDERR.puts("Mapwrap: srs is #{srs}")
	STDERR.puts("Mapwrap: proj is #{proj}")
	STDERR.puts("Mapwrap: Using mapfile #{mapfile}")
	
	#Verify that the mapfile is valid..
	if not mapfile
		msg = ""
		if conf['maps']
			msg += " <b>no map file specified</b> <br />"+
			msg += "Options are: <ul><li>" +
			msg += conf['maps'].keys.join("</li><li>") +
			msg += " </li></ul>"
		else
			msg += "<b>Error: no maps.</b>"
		end
		raise RuntimeError.new(msg)
	end
	
	STDERR.puts "mapfile: #{mapfile}" if $test
	
	wms_params = {}
	wms_params['SERVICE'] = 'WMS' unless pfind( 'SERVICE', cgi.params)
	wms_params['REQUEST'] = 'GetCapabilities' unless pfind( 'REQUEST', cgi.params)
	
	STDERR.puts wms_params.inspect if $test
	if wms_params.size > 0 
	  wms_query = wms_params.map { |k,v| "#{CGI.escape(k)}=#{CGI.escape(v)}" }.join('&')
	  ENV["QUERY_STRING"]  = wms_query + "&" + ENV["QUERY_STRING"] 
	end
	
	# TODO: fix ESRI exception problems
	if ( etype = pfind( 'EXCEPTIONS', cgi.params ) )
	  if not %w{ blank image xml }.include?(etype) 
	    # ESRI client probably doing it wrong, force to XML
	    ENV["QUERY_STRING"] += "&EXCEPTIONS=XML"
	    STDERR.puts(ENV["QUERY_STRING"])
	  end
	end
	
	## unless pfind('map',cgi.params)
	if (cgi.params['map'].size == 0 ) and ( cgi.params['MAP'].size == 0 )
	  ENV["QUERY_STRING"]="map=#{mapfile}&"+ENV["QUERY_STRING"]
	  envsh = (File.exists? conf['envsh'])?("source #{conf['envsh']}"):''
	  system(" #{envsh} ; #{mapserv} ")
	else
	  # user being naughty and trying to find themselves a mapfile
	  raise RuntimeError("Sorry, You can't specifiy a map file with this service" )
	end
rescue  RuntimeError=> bang
	cgi.out do
	    cgi.html do
		"An Error Occurred: " +	bang.to_s
	    end
	end
rescue Exception => bang
	cgi.out do
		cgi.html do
			"An Major Error Occurred: " +	bang.to_s +
			"<p> <strong>Backtrace:</strong>" +
			"<ul> " +
			"<li>" +
			bang.backtrace.join("</li><li>") +
			"</li>"+
			"</ul>"
		end
	end
end
