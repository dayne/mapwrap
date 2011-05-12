Map Wrap - MapServer wrapper
============================

A MapServer CGI wrapper that simplifies the URLs to your WMS services and provides the following features:

* defaults SERVICE to WMS
* defaults REQUEST to GetCapabilities
* allows for projection optimized mapfiles
* accepts both POST and GET requests
* simple name alias for a map

*Why is that useful?*

I like simple URLs to remember and hiding my secrets.  Users do not need to know, and I should have to remember, the path to my mapfiles.  I hate having to specify `?SERVICE=WMS&REQUEST=GetCapabilities` when doing my sanity check with curl.


INSTALL:
--------

To use this handy wrapper script you have to setup a few things.


* create an user friendly alias (for your users, not you)

 > See apache config section below for example

* configure the FUN_PREFIX to the prefix you choose

>  `FUN_PREFIX = "/map"`

* point the CONFIG_FILE at the correct location (defaults to ../conf.yml)

>  `CONFIG_FILE = "/path/to/mapwrap/conf.yml"`

* Creat the config file (see below)

* tail -f error.log and access.log, reload apache

* Check the output of a GetCapabilities:

> `curl 'http://localhost/map/example' | less`


Apache Configuration
--------------------

The following can be slide into appropriate Apache config section or `/etc/httpd/conf.d/mapwrap.conf` for a global configuration:

    <Directory "/path/to/mapwrap/cgi-bin">
      AllowOverride None
      Options ExecCGI  FollowSymLinks
      AddHandler cgi-script .rb
      Order allow,deny
      Allow from all
    </Directory>
    # The following is the FUN_PREFIX=/map
    Alias /map /path/to/mapwrap/cgi-bin/mapwrap.rb

Configuration: conf.yml
-----------------------

Hopefully the only part you have to maintain after you've set things up correctly.  To get started just do a somple `cp conf.yml.default conf.yml`

``` yaml
mapserv: /opt/mapping_tools/bin/mapserv.svn
envsh: /opt/mapping_tools/setup.sh
maps:
  bluemarble: /www/wms/apps/mapserver/maps/bluemarble.map
  example: /www/wms/apps/mapserver/maps/bluemarble.map
  spot_pan:
    default: /www/wms/apps/mapserver/maps/spot_pan.map
    900913: /www/wms/apps/mapserver/maps/spot_pan-900913.map
```

The mapserv and envsh options are optional.  If you have a good CGI environment with mapserv and libraries available then delete those lines.

The maps section takes a name and a path to a mapfile.  If you want to have an optimized mapfile for multiple pre-projected datasets then break it apart with a default line and a line for each EPSG code you've got.

Credit where credit is due
--------------------------

* [spruceboy](http://github.com/spruceboy) is the man behind the curtain.
