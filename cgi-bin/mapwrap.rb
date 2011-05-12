#!/usr/local/bin/ruby
=begin
USAGE:

INSTALL:
To use this handy wrapper script you have to setup a few things.
  1) create an user friendly alias (for your users, not you)
    a) the friendly Apache Alias
       Alias /map /www/wms.soy/cgi-bin/mapwrap.cgi
    b) configure the FUN_PREFIX
       FUN_PREFIX = "/map"
  2) point the CONFIG_FILE at the correct location
    CONFIG_FILE = "/www/wms.soy/apps/mapserver/conf.yml"
  3) create the CONFIG_FILE.  It should look like:

maps:
  spot_pan: 
    default: /www/wms.soy/apps/mapserver/maps/spot_pan.map
    900913: /www/wms.soy/apps/mapserver/maps/spot_pan-900913.map
  spot_ms: /www/wms.soy/apps/mapserver/maps/spot_ms.map
  bluemarble: /www/wms.soy/apps/mapserver/maps/bluemarble.map

  4) tail -f error.log and access.log, reload apache
  5) curl 'http://localhost/fun/example&REQUEST=GetCapabilities&SERVICE=wms'
  6) cross your fingers and be happy?
=end
CONFIG_FILE = "/home/webdev/mapwrap/conf.yml"
FUN_PREFIX = "/map"

require 'cgi'
require 'yaml'
cgi = CGI.new("html4")
conf = YAML.load_file(CONFIG_FILE)
mapserv="/opt/mapping_tools/bin/mapserv.svn"

# figure out which mapfile to use by parsing the fun:
# map = ENV['REQUEST_URI'].split('?')[0].split('/').last
magic = ENV['REQUEST_URI'].split('?')[0].split('/') if ENV['REQUEST_URI']
magic = ['a','b','c'] unless magic
empty = magic[0]
fun = magic[1]
map = magic[2]
case magic[3]
  when 'test' then 
    $test = true
  else
    #STDERR.puts "ho ho ho, no magic[3]"
end


if "/#{fun}" != FUN_PREFIX
  # TODO error out here as the script has been run badly
end

#STDERR.puts "root=#{root} | fun=#{fun} | map=#{map}"

#TODO: add a thing to optimize for pre-projected map file

srs = cgi['srs'] || cgi['SRS'] || cgi['crs'] || cgi['CRS']
srs = srs.join() if (srs.class == Array)
proj = nil
proj = srs.split(":").last.to_i if (srs)
#STDERR.puts(script + ": proj #{proj} from (#{srs})") if (proj)

#if proj is in the maps thing use it or just use default

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
  # TODO ERROR OUT
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
if ( pfind( 'EXCEPTION', cgi.params ) )
  if not %w{ blank image xml }.include?(cgi.params['EXCEPTION'].downcase)
    # ESRI client probably doing it wrong
    # pset('exception', 'xml')
  end
end
=end

if (cgi.params['map'].size == 0 ) and ( cgi.params['MAP'].size == 0 )
  ENV["QUERY_STRING"]="map=#{mapfile}&"+ENV["QUERY_STRING"]
  system(". /opt/mapping_tools/setup.sh; #{mapserv} ")
else
  # user being naughty and trying to find themselves a mapfile
  cgi.out{ "Sorry, You can't specifiy a map file with this service" }
end


=begin
if (ENV["REQUEST_METHOD"] == "GET" ) 
  if (cgi.params['map'].size == 0 ) and ( cgi.params['MAP'].size == 0 )
    ENV["QUERY_STRING"]="map=#{mapfile}&"+ENV["QUERY_STRING"]
    system(". /opt/mapping_tools/setup.sh; #{mapserv} ")
  else
    # user being naughty and trying to find themselves a mapfile
    cgi.out{ "Sorry, You can't specifiy a map file with this service" }
  end
else
  cgi.out{ "Sorry, I only understand GET requests and you are using POST." } 
  STDERR.puts("#{script}:post problem.")
end
=end
