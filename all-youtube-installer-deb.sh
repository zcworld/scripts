#!/bin/bash

echo -ne "Enter AllTube hostname/domain: "
read DOMAIN

echo -ne "Enter server IP: "
read SRVIP

# Use proper DNS servers
cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

# Update system
apt-get update && apt-get upgrade

# Install git
apt-get -y install git

# Install nginx
apt-get -y install nginx

# Install some required packages
apt-get -y install wget curl sudo vim apt-transport-https gettext unzip
apt-get -y install gcc make

# Install Yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
apt-get update && sudo apt-get install yarn

# Install NodeJS
wget -qO- https://deb.nodesource.com/setup_14.x | bash -
apt-get -y install nodejs
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
apt-get -y update && sudo apt-get -y install yarn

# Install PHP
apt-get -y install php php-fpm php-mbstring php-intl php-xmlwriter php-gmp php-zip
cd ~
curl -sS https://getcomposer.org/installer -o composer-setup.php
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
hash -r

# Disable/Stop Apache2
systemctl disable apache2
systemctl stop apache2
killall -9 apache2

# Clone AllTube from GitHub
mkdir -p /var/www/
cd /var/www
git clone https://github.com/Rudloff/alltube.git alltube
chown www-data:www-data alltube/ -R
cd alltube/
chown www-data:www-data /var/www/alltube -R
chmod 777 templates_c/
yarn install
composer install

# You should create a configuration file for the script from the default config.example.yml
# Config file is in /var/www/alltube/config/config.example.yml
cp /var/www/alltube/config/config.example.yml /var/www/alltube/config/config.yml
chown www-data:www-data /var/www/alltube/config/config.yml

# Enable services
systemctl enable nginx php7.0-fpm.service

# Create nginx vhost file
rm -f /etc/nginx/sites-available/*
rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/sites-available/"$DOMAIN".conf <<EOF
server {
        server_name $DOMAIN $SRVIP;
        listen 80;

        root /var/www/alltube;
        index index.php;

        access_log  /var/log/nginx/$DOMAIN.access.log;
        error_log   /var/log/nginx/$DOMAIN.error.log;

        types {
                text/html   html htm shtml;
                text/css    css;
                text/xml    xml;
                application/x-web-app-manifest+json   webapp;
        }

        # Deny access to dotfiles
        location ~ /\. {
                deny all;
        }
EOF

cat >> /etc/nginx/sites-available/"$DOMAIN".conf <<'EOF'

        location / {
                try_files $uri /index.php?$args;
        }

        location ~ \.php$ {
                try_files $uri /index.php?$args;

                fastcgi_param     PATH_INFO $fastcgi_path_info;
                fastcgi_param     PATH_TRANSLATED $document_root$fastcgi_path_info;
                fastcgi_param     SCRIPT_FILENAME $document_root$fastcgi_script_name;

                fastcgi_pass unix:/run/php/php7.0-fpm.sock;
                fastcgi_index index.php;
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_intercept_errors off;

                fastcgi_buffer_size 16k;
                fastcgi_buffers 4 16k;

                include fastcgi_params;
        }
}
EOF

ln -sf /etc/nginx/sites-available/"$DOMAIN".conf /etc/nginx/sites-enabled/"$DOMAIN"
systemctl restart nginx

# Install AV codecs
apt-get -y install libav-tools
