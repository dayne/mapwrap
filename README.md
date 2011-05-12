Map Wrap - MapServer wrapper
============================

INSTALL:
--------

To use this handy wrapper script you have to setup a few things.
  1) create an user friendly alias (for your users, not you)
    a) the friendly Apache Alias
       Alias /map /www/wms.soy/cgi-bin/mapwrap.rb
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


Apache Configuration
--------------------
```
<Directory "/path/to/mapwrap/cgi-bin">
  AllowOverride None
  Options ExecCGI  FollowSymLinks
  AddHandler cgi-script .rb
  Order allow,deny
  Allow from all
</Directory>


Alias /map /path/to/mapwrap/cgi-bin/mapwrap.rb
```
