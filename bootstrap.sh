#!/usr/bin/env bash
#### CONFIG ####################

#php
#version
pv=7.0
# memo: find extensions by sudo apt-cache search php7-*
php=(php$pv php$pv-common php$pv-dev php$pv-cli)
extensions=(php$pv-fpm php$pv-curl php$pv-gd php$pv-mcrypt php$pv-mbstring libapache2-mod-php$pv php$pv-mysql php$pv-intl php$pv-zip php$pv-json php$pv-tidy php$pv-xsl php$pv-opcache php$pv-pspell php-xdebug php-geoip php-solr php-xml)

#credentials mySql phpMyAdmin
pwd=vagrant
pma=vagrant

PROJECT='nakade'
MAIL='webmaster@nakade.de'
DOMAIN='nakade.de'

#####################################
# FUNCTIONS #########################
#####################################
function hasPkg {
echo "check package $1"
if [ $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  #1=false
  return 1;
fi
  #0=true
return 0;
}
################
function installPkg {
if hasPkg $1;
then
  echo "[OK]"
else
  echo "install $1 ..."
  apt-get -y install $1 > /dev/null;
fi
}
################
function installPhpMyAdmin {
package=phpmyadmin
if hasPkg $package;
then
  echo "[OK]"
else
  echo "install $package ..."
  debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
  debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $pma"
  debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $pma"
  debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $pma"
  debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
  apt-get -y install $package > /dev/null;
fi
}
################
function installMySql {
package=mysql-server
if hasPkg $package;
then
  echo "[OK]"
else
  echo "install $package ..."
  debconf-set-selections <<< "mysql-server mysql-server/root_password password $pwd"
  debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $pwd"
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y install $package > /dev/null
  echo "set privileges for root"
  mysql -uroot -p$pwd -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '"$pwd"'; FLUSH PRIVILEGES;" 2>&1 | grep -v "Warning: Using a password"
fi
}
#######################################
export DEBIAN_FRONTEND=noninteractive

echo "Provisioning virtual machine..."

#REPO
echo "add php7 repository..."
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
apt-get update > /dev/null

#GIT
#installPkg git

#PYTHON
installPkg python-software-properties
installPkg software-properties-common

#WEB SERVER
installPkg apache2

#DATABASE TOOL
installPkg debconf-utils

#DATABASE
installMySql

#PHP MY ADMIN
installPhpMyAdmin

#PHP
apt-get update > /dev/null
echo "install php $pv ..."
for i in ${php[@]}; do
   installPkg ${i}
done

#PHP EXTENSIONS
echo "install php extensions..."
for i in ${extensions[@]}; do
   installPkg ${i}
done

#PHP UNIT
echo "install phpUnit ..."
wget -q https://phar.phpunit.de/phpunit.phar > /dev/null
chmod +x phpunit.phar > /dev/null
mv phpunit.phar /usr/local/bin/phpunit > /dev/null

#COMPOSER
echo "install composer ..."
cd ~
curl -Ss https://getcomposer.org/installer | php
mv ~/composer.phar /usr/local/bin/composer.phar
ln -fs /usr/local/bin/composer.phar /usr/local/bin/composer

#JavaScriptFrameworks
installPkg nodejs
installPkg npm

#project dir
DIR=info
echo "create project folder /var/www/html/{PROJECT}"
mkdir -p /var/www/html/${PROJECT}
mkdir -p /var/www/html/${DIR}


#phpinfo
echo "create phpinfo ..."
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/${DIR}/info.php
echo "use localhost:8080/info.php ..."


#setup hosts file
echo "create virtual host file for info.php"

VHOST=$(cat <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName info.localhost

    DocumentRoot "/var/www/html/${DIR}"
    DirectoryIndex info.php

    LogLevel crit

    ErrorLog  /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
</VirtualHost>
EOF
)
echo "${VHOST}" > /etc/apache2/sites-available/${DIR}.conf
a2ensite ${DIR}.conf

#setup hosts file for project
echo "create virtual host file for " . ${PROJECT}

VHOST=$(cat <<EOF
<VirtualHost *:80>
    ServerAdmin ${MAIL}
    ServerName localhost

    DocumentRoot "/var/www/html/${PROJECT}/web"
    <Directory "/var/www/html/${PROJECT}/web">
        AllowOverride All
        Order Allow,Deny
        Allow from All
        <IfModule mod_rewrite.c>
            Options -MultiViews
            RewriteEngine On
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteRule ^(.*)$ app.php [QSA,L]
        </IfModule>
    </Directory>

    # uncomment the following lines if you install assets as symlinks
    # or run into problems when compiling LESS/Sass/CoffeeScript assets
    # <Directory /var/www/html/${PROJECT}>
    #     Options FollowSymlinks
    # </Directory>

    <Directory /var/www/html/${PROJECT}/web/bundles>
        <IfModule mod_rewrite.c>
            RewriteEngine Off
        </IfModule>
    </Directory>

    LogLevel error

    ErrorLog  /var/log/apache2/${PROJECT}_error.log
    CustomLog /var/log/apache2/${PROJECT}_access.log combined
</VirtualHost>
EOF
)
echo "${VHOST}" > /etc/apache2/sites-available/000-default.conf

echo "ServerName localhost" >> /etc/apache2/apache2.conf

#timezone
timedatectl set-timezone Europe/Berlin

# enable mod_rewrite
a2enmod rewrite

# restart apache
service apache2 restart
echo "cd /vagrant" >> /home/ubuntu/.bashrc

echo 'SignIn on your VagrantBox ("vagrant ssh") and make a "composer install"'
