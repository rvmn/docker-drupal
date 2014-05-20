FROM ubuntu:14.04

Maintainer Luis Elizondo "lelizondo@gmail.com"

ENV DEBIAN_FRONTEND noninteractive

# Update system
RUN apt-get update && apt-get dist-upgrade -y

# Ensure UTF-8
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Install PHP
RUN apt-get -y install php5-fpm php5-mysql php-apc php5-imap php5-mcrypt php5-curl php5-cli php5-gd php5-common php-pear curl php5-json php5-memcache

# Install Nginx
RUN apt-get -y install nginx

# Install MySQL
RUN apt-get -y install mysql-client mysql-server

# Install Memcached
RUN apt-get -y install memcached

# Install Varnish
RUN apt-get -y install varnish

# Prevent daemon start during install
RUN	echo '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

# Install Supervisor
RUN apt-get install -y supervisor 
RUN mkdir -p /var/log/supervisor

# Install SSHD
RUN apt-get install -y openssh-server
RUN mkdir /var/run/sshd && echo 'root:root' |chpasswd

# Install Utilities
RUN apt-get install -y vim curl

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/
RUN mv /usr/bin/composer.phar /usr/bin/composer

# Install Drush using composer
RUN composer global require drush/drush:dev-master

# Add Nginx file
ADD ./config/default /etc/nginx/sites-available/default

# Varnish
ADD ./config/drupal.vcl /etc/varnish/drupal.vcl
# ADD ./status.php /var/www/status.php

# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###
### Configurations
###

# Supervisor starts everything
ADD	./config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Configure MySQL
RUN sed -i -e"s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

# Create database
RUN mysqladmin -uroot -p root create drupal

RUN drush vset cache 1 
RUN drush vset page_cache_maximum_age 3600 
RUN drush vset varnish_version 3 

# Configure PHP RPM
RUN sed -i 's/memory_limit = .*/memory_limit = 196M/' /etc/php5/fpm/php.ini

# Drupal Settings
ADD ./config/settings.php.append /tmp/settings.php.append
RUN cat /tmp/settings.php.append >> /var/www/sites/default/settings.php
RUN rm /tmp/settings.php.append

EXPOSE 80
EXPOSE 22
EXPOSE 3306
EXPOSE 6081

#Supervisord
CMD ["/usr/bin/supervisord", "-n"]