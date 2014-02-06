#!/bin/sh

port_dir="/usr/ports/"
ports="www/nginx www/spawn-fcgi db/mysql56-client db/php55-mysql lang/php55"

cd $port_dir/ports-mgmt/dialog4ports && make install clean distclean

for port in $ports
do
        cd $port_dir$port && make config-recursive 
done

for port in $ports
do
        cd $port_dir$port && make install
done


for port in $ports
do
        cd $port_dir$port && make clean dist-clean
done

echo '' >> /etc/rc.conf
echo 'nginx_enable="YES"' >> /etc/rc.conf
echo 'memcached_enable="YES"' >> /etc/rc.conf
echo 'spawn_fcgi_enable="YES"' >> /etc/rc.conf
echo 'spawn_fcgi_bindaddr=""' >> /etc/rc.conf
echo 'spawn_fcgi_bindport=""' >> /etc/rc.conf
echo 'spawn_fcgi_bindsocket="/var/run/spawn_fcgi.socket"' >> /etc/rc.conf
echo 'spawn_fcgi_bindsocket_mode="0700"' >> /etc/rc.conf


cp /usr/local/etc/nginx/nginx.conf /usr/local/etc/nginx/nginx.conf.auto-backup
chmod 644 /usr/local/etc/nginx/nginx.conf

echo '# use fastcgi for all php files' >> /usr/local/etc/nginx/nginx.conf
echo '#        location ~ \.php$' >> /usr/local/etc/nginx/nginx.conf
echo '#        {' >> /usr/local/etc/nginx/nginx.conf
echo '#          root           /usr/local/www/apache22/data;' >> /usr/local/etc/nginx/nginx.conf
echo '#          fastcgi_pass   unix:/var/run/spawn_fcgi.socket;' >> /usr/local/etc/nginx/nginx.conf
echo '#          fastcgi_index  index.php;' >> /usr/local/etc/nginx/nginx.conf
echo '#          fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;' >> /usr/local/etc/nginx/nginx.conf
echo '#          include        fastcgi_params;' >> /usr/local/etc/nginx/nginx.conf
echo '#        }' >> /usr/local/etc/nginx/nginx.conf

