#!/usr/local/bin/ruby
=begin

A MapServer CGI wrapper that simplifies the URLs to your WMS services.

http://github.com/dayne/mapwrap

* defaults SERVICE to WMS
* defaults REQUEST to GetCapabilities
* allows for projection optimized mapfiles
* accepts both POST and GET requests

=end
FUN_PREFIX = "/map"
CONFIG_FILE = "/path/to/mapwrap/conf.yml"

unless File.exists?(CONFIG_FILE)
# bad path to config, lets see if we can find it in ../conf.yml
  poke = File.join(File.dirname(__FILE__),'..','conf.yml')
  CONFIG_FILE = poke if File.exists?( poke )
end

require 'cgi'
require 'yaml'
cgi = CGI.new("html4")
conf = YAML.load_file(CONFIG_FILE)

if conf['mapserv']
  mapserv=conf['mapserv']
else
  mapserv='mapserv' # rely on environment path to provide mapserv
end

# figure out which mapfile to use by parsing the fun:
magic = ENV['REQUEST_URI'].split('?')[0].split('/') if ENV['REQUEST_URI']
empty = magic[0]
fun = magic[1]
map = magic[2]
case magic[3]
  when 'test' then 
    $test = true
  else
    # no special sauce asked for, none given
end


if "/#{fun}" != FUN_PREFIX
  # TODO error out here as the script has been run badly
end

srs = cgi['srs'] || cgi['SRS'] || cgi['crs'] || cgi['CRS']
srs = srs.join() if (srs.class == Array)
proj = nil
proj = srs.split(":").last.to_i if (srs)


# if proj is in the maps thing use it or just use default

if map and conf['maps'][map]
  mapfile = conf['maps'][map]
  if mapfile.class == Hash
    if mapfile[srs]
      mapfile = mapfile[srs]
    else
      mapfile = mapfile['default']
    end
  end
else
  # TODO ERROR OUT instead of this silly default
  mapfile =  conf['default']
end

STDERR.puts "mapfile: #{mapfile}" if $test

def pfind( name, location )
  result = false
  [name, name.upcase, name.downcase].each do |n|
    next if result
    result = location[n] if location[n] and location[n].size > 0 
  end
  STDERR.puts "found #{result} for #{name}" if $test
  result
end

=begin
def pset( name, value )
  # 
end
=end

wms_params = {}
wms_params['SERVICE'] = 'WMS' unless pfind( 'SERVICE', cgi.params)
wms_params['REQUEST'] = 'GetCapabilities' unless pfind( 'REQUEST', cgi.params)

STDERR.puts wms_params.inspect if $test
if wms_params.size > 0 
  wms_query = wms_params.map { |k,v| "#{CGI.escape(k)}=#{CGI.escape(v)}" }.join('&')
  ENV["QUERY_STRING"]  = wms_query + "&" + ENV["QUERY_STRING"] 
end

=begin
## unfinished thoughts for ESRI exception problems
if ( etype = pfind( 'EXCEPTION', cgi.params ) )
  if not %w{ blank image xml }.include?(etype) 
    # ESRI client probably doing it wrong, force to XML
    pset('EXCEPTION', 'XML')
  end
end
=end

## unless pfind('map',cgi.params)
if (cgi.params['map'].size == 0 ) and ( cgi.params['MAP'].size == 0 )
  ENV["QUERY_STRING"]="map=#{mapfile}&"+ENV["QUERY_STRING"]
  envsh = (File.exists? conf['envsh'])?("source #{conf['envsh']}"):''
  system(" #{envsh} ; #{mapserv} ")
else
  # user being naughty and trying to find themselves a mapfile
  cgi.out{ "Sorry, You can't specifiy a map file with this service" }
end
