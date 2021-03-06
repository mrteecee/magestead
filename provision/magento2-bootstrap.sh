#!/usr/bin/env bash

DB=$1;
domain=$2;

echo "--- Bootstrapping Magento 2 ---"

# Clone the repo
cd /vagrant;
if [ ! -d /vagrant/magento2 ]; then
    echo "Cloning Magento 2 Repo"
    git clone https://github.com/magento/magento2.git
fi

echo "Setting Permissions"
# Set permissions
cd magento2;
sudo find . -type d -exec chmod 700 {} \; && sudo find . -type f -exec chmod 600 {} \; && sudo chmod +x bin/magento
/usr/local/bin/composer install;

echo "Exporting PATH"
# Export the path to use global
export PATH=$PATH:/vagrant/magento2/bin;

echo "Setting NGINX Server Block"
# Create the NGINX server block
block="server {
    listen 80;
    server_name $domain;
    set \$MAGE_ROOT /vagrant/magento2;
    set \$MAGE_MODE developer;

    root \$MAGE_ROOT/pub;

    index index.php;
    autoindex off;
    charset off;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location /pub {
        alias \$MAGE_ROOT/pub;
    }

    location /static/ {
        if (\$MAGE_MODE = \"production\") {
            expires max;
        }
        location ~* \.(ico|jpg|jpeg|png|gif|svg|js|css|swf|eot|ttf|otf|woff|woff2)$ {
            add_header Cache-Control \"public\";
            expires +1y;

            if (!-f \$request_filename) {
                rewrite ^/static/(version\d*/)?(.*)$ /static.php?resource=\$2 last;
            }
        }
        location ~* \.(zip|gz|gzip|bz2|csv|xml)$ {
            add_header Cache-Control \"no-store\";
            expires    off;

            if (!-f \$request_filename) {
               rewrite ^/static/(version\d*/)?(.*)$ /static.php?resource=\$2 last;
            }
        }
        if (!-f \$request_filename) {
            rewrite ^/static/(version\d*/)?(.*)$ /static.php?resource=\$2 last;
        }
    }

    location /media/ {
        try_files \$uri \$uri/ /get.php?\$args;
        location ~* \.(ico|jpg|jpeg|png|gif|svg|js|css|swf|eot|ttf|otf|woff|woff2)$ {
            add_header Cache-Control \"public\";
            expires +1y;
            try_files \$uri \$uri/ /get.php?\$args;
        }
        location ~* \.(zip|gz|gzip|bz2|csv|xml)$ {
            add_header Cache-Control \"no-store\";
            expires    off;
            try_files \$uri \$uri/ /get.php?\$args;
        }
    }

    location /media/customer/ {
        deny all;
    }

    location /media/downloadable/ {
        deny all;
    }

    location ~ /media/theme_customization/.*\.xml$ {
        deny all;
    }

    location /errors/ {
        try_files \$uri =404;
    }

    location ~ ^/errors/.*\.(xml|phtml)$ {
        deny all;
    }

    location ~ cron\.php {
        deny all;
    }

    location ~ (index|get|static|report|404|503)\.php$ {
        try_files \$uri =404;
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_index  index.php;

        fastcgi_param  PHP_FLAG  \"session.auto_start=off \n suhosin.session.cryptua=off\";
        fastcgi_param  PHP_VALUE \"memory_limit=256M \n max_execution_time=600\";
        fastcgi_read_timeout 600s;
        fastcgi_connect_timeout 600s;
        fastcgi_param  MAGE_MODE \$MAGE_MODE;

        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
        include        fastcgi_params;
    }
}
"
echo "Restart Services"
# Add the block and restart PHP-FPM and NGINX
echo "$block" > "/etc/nginx/conf.d/$domain"
sudo service nginx restart
sudo service php-fpm restart

echo "Installing Magento 2"
# Run the setup wizard from command line
magento setup:install --base-url=http://$domain/ \
--db-host=localhost \
--db-name=$DB \
--db-user=root \
--db-password=vagrant \
--admin-firstname=Magento \
--admin-lastname=Admin \
--admin-email=admin@admin.com \
--admin-user=admin \
--admin-password=password123 \
--language=en_GB \
--currency=GBP \
--timezone=Europe/London \
--use-rewrites=1 \
--session-save=db

echo "Magento admin username = admin";
echo "Magento admin password = password123";
echo "Magento installed at http://$domain/. Remember and set your hosts file.";
