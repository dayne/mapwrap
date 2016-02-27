#!/usr/bin/env ruby
#
# A MapServer CGI wrapper that simplifies the URLs to your WMS services.
#
# http://github.com/dayne/mapwrap
#
# * defaults SERVICE to WMS
# * defaults REQUEST to GetCapabilities
# * allows for projection optimized mapfiles
# * accepts both POST and GET requests
#
#
# basic mapper scheme..
#
# 1) loop though configs:
#   compare each item, maching prefix with "url",
#   if it matchs, then use that item for
# 2) if nothing matches, check "default", compare with "prefix"
#   if it matches use that item
#   if so, then attempt to match with the items in "map"
# 3) if nothing matches, then generate an error.
#
require 'cgi'
require 'yaml'
require 'mixlib/shellout'

##
# locate items in CGI params
def pfind(name, location)
  result = false
  [name, name.upcase, name.downcase].each do |n|
    next if result
    result = location[n] if location[n] && location[n].size > 0
  end
  STDERR.puts "found #{result} for #{name}" if $test
  result
end

# invoke CGI
cgi = CGI.new('html4')
conf = nil
url = nil

##
# Load config, in a catch block, if errors accor rase an
# RuntimeError with the message to be displayed to the user.
begin
  # take first bit of the URI
  conf_token = ENV['REQUEST_URI'].split('?')[0].split('/')[1]
  # replace any non-word chars with "-"
  # in an attempt to clean up any requests for junk/hacks
  conf_token.gsub!(/\W+/, '-')
  # config file is in /ogc/maps/{token}/map_wrap/conf.yml
  conf_file = "/ogc/maps/#{conf_token}/map_wrap/conf.yml"

  unless File.exist?(conf_file)
    raise "Cannot access mapwrap config file at #{conf_file}"
  end

  conf = File.open(conf_file) { |fd| YAML.load(fd) }

  #remove the /token part of the url, now that we know what set to load.
  url = ENV['REQUEST_URI'].split('?')[0]
  url.slice!('/' + conf_token)
  #remove trailing slash
  url.chomp!("/")

rescue  RuntimeError => problem
  cgi.out do
    cgi.html do
      'An Error Occurred: ' + problem.to_s
    end
  end
end

STDERR.puts("Mapwrap: url is #{url}")

# First look in "configs", and see if the url has a direct mapping..
conf_item = conf['configs'][url] if conf['configs'] && conf['configs'].keys.length > 0


#default timeout of 60 seconds
unless conf['defaults']['timeout']
	conf['defaults']['timeout'] = 60*60
end

if conf_item
  # for each item we need a "mapserv" and a "envsh"
  # if these don't exist, copy them from the default set.
  %w(mapserv envsh timeout).each { |conf_key_set| conf_item[conf_key_set] = conf['defaults'][conf_key_set] unless conf_item[conf_key_set] }
  conf = conf_item
else
  # no direct url mapping, use defaults.
  conf = conf['defaults']
end

begin
  ##
  # In a catch block - if errors accor rase an RuntimeError
  # with the message to be displayed to the user.

  # verfiy that the mapserv path is set..
  mapserv = if conf['mapserv']
              conf['mapserv']
            else
              'mapserv' # rely on environment path to provide mapserv
            end

  # A little more verbose than is require, but x||y||z logic does not appear to work..
  srs = cgi['srs']
  srs = cgi['SRS'] if srs.nil? || srs == ''
  srs = cgi['crs'] if srs.nil? || srs == ''
  srs = cgi['CRS'] if srs.nil? || srs == ''

  srs = srs.join if srs.class == Array
  proj = srs.split(':').last.to_i if srs

  # if proj is in the maps thing use it or just use default
  if conf['maps'] # Using maps
    if url && conf['maps'][url]
      mapfile = conf['maps'][url]
      if mapfile.class == Hash
        mapfile = if proj && mapfile[proj]
                    mapfile[proj]
                  else
                    mapfile['default']
                  end
       end
    end
  else # not using maps section..
    if conf['projections'].class != Hash
      raise RuntimeError.new('<b>MapWrap Error:</b>  <br />' \
                  "<tt>projections block is not quite correct for \"#{map}\".</tt>")
    end
    mapfile = if proj && conf['projections'][proj]
                conf['projections'][proj]
              else
                conf['projections']['default']
                          end
  end

  STDERR.puts("Mapwrap: srs is #{srs}")
  STDERR.puts("Mapwrap: proj is #{proj}")
  STDERR.puts("Mapwrap: Using mapfile #{mapfile}")

  # Verify that the mapfile is valid..
  unless mapfile
    msg = ''
    if conf['maps']
      msg += ' <b>no map file specified</b> <br />' + msg += 'Options are: <ul><li>' +
                                                             msg += conf['maps'].keys.join('</li><li>') +
                                                                    msg += ' </li></ul>'
    else
      msg += '<b>Error: no maps.</b>'
    end
    raise RuntimeError.new(msg)
  end

  wms_params = {}
  wms_params['SERVICE'] = 'WMS' unless pfind('SERVICE', cgi.params)
  wms_params['REQUEST'] = 'GetCapabilities' unless pfind('REQUEST', cgi.params)

  if wms_params.size > 0
    wms_query = wms_params.map { |k, v| "#{CGI.escape(k)}=#{CGI.escape(v)}" }.join('&')
    ENV['QUERY_STRING'] = wms_query + '&' + ENV['QUERY_STRING']
  end

  # TODO: fix ESRI exception problems
  # This is required as some ESRI clients request invald expection types
  if (etype = pfind('EXCEPTIONS', cgi.params))
    unless %w(blank image xml).include?(etype)
      # ESRI client probably doing it wrong, force to XML
      ENV['QUERY_STRING'] += '&EXCEPTIONS=XML'
      STDERR.puts(ENV['QUERY_STRING'])
    end
  end

  unless File.exist? conf['envsh']
    raise RuntimeError("Mapping tools environment script #{conf['envsh']} does not appear to exist.")
  end

  if (cgi.params['map'].size == 0) && (cgi.params['MAP'].size == 0)
    ENV['QUERY_STRING'] = "map=#{mapfile}&" + ENV['QUERY_STRING']
    envsh = (File.exist? conf['envsh']) ? "source #{conf['envsh']}" : ''
    command = Mixlib::ShellOut.new("#{envsh} ; #{mapserv}", live_stdout: STDOUT, live_stderr: STDERR, timeout: conf['timeout'])
    command.run_command
  else
    # user being naughty and trying to find themselves a mapfile
    raise RuntimeError("Sorry, You can't specifiy a map file with this service")
  end
rescue RuntimeError => bang
  STDERR.puts("Mapwrap: FAILED request: #{ENV['REQUEST_URI']}")
  cgi.out do
    cgi.html do
      'An Error Occurred: ' +	bang.to_s
    end
  end
rescue Exception => bang
  STDERR.puts("Mapwrap: FAILED request: #{ENV['REQUEST_URI']}")
  cgi.out do
    cgi.html do
      'An Major Error Occurred: ' +	bang.to_s +
        '<p> <strong>Backtrace:</strong>' \
        '<ul> ' \
        '<li>' +
        bang.backtrace.join('</li><li>') +
        '</li>'\
        '</ul>'
    end
  end
end
