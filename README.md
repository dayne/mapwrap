Map Wrap - MapServer wrapper
============================

A MapServer CGI wrapper that simplifies the URLs to your WMS services and provides the following features:

* defaults SERVICE to WMS
* defaults REQUEST to GetCapabilities
* allows for projection optimized mapfiles
* accepts both POST and GET requests


INSTALL:
--------

To use this handy wrapper script you have to setup a few things.


* create an user friendly alias (for your users, not you)

 > See apache config section below for example

* configure the FUN_PREFIX to the prefix you choose

>  `FUN_PREFIX = "/map"`

* point the CONFIG_FILE at the correct location (defaults to ../conf.yml)

>  `CONFIG_FILE = "/path/to/mapwrap/conf.yml"`

* create the CONFIG_FILE.  It should look like (see conf.yml.example):

``` yaml
maps:
  bluemarble: /www/wms.soy/apps/mapserver/maps/bluemarble.map
  example: /www/wms.soy/apps/mapserver/maps/bluemarble.map
  spot_pan: 
    default: /www/wms.soy/apps/mapserver/maps/spot_pan.map
    900913: /www/wms.soy/apps/mapserver/maps/spot_pan-900913.map
```

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
