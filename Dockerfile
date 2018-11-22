FROM ubuntu:18.04

# Surpress Upstart errors/warning
RUN dpkg-divert --local --rename --add /sbin/initctl \
    && ln -sf /bin/true /sbin/initctl

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y supervisor \
        git \
        pwgen \
        bash-completion \
        hostname \
        vim \
        screen \
        wget \
        curl \
        tree \
        htop \
        zsh \
        iputils-ping \
        net-tools \
        telnet \
        tzdata \
    && chsh -s /bin/zsh \
    && apt-get autoremove -y \
    && apt-get clean \
    && apt-get autoclean
RUN cp /usr/share/zoneinfo/Europe/London /etc/localtime



RUN apt-get install -y software-properties-common \
    language-pack-en-base

RUN add-apt-repository ppa:nginx/stable

RUN apt-get install -y nginx

RUN apt-get autoremove -y
RUN apt-get clean
RUN apt-get autoclean

#tweek nginx config
RUN sed -i -e '/worker_processes/c\worker_processes  5;' /etc/nginx/nginx.conf
RUN sed -i -e '/keepalive_timeout/c\keepalive_timeout  2;' /etc/nginx/nginx.conf
RUN sed -i -e '/client_max_body_size/c\client_max_body_size 100m;' /etc/nginx/nginx.conf
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

# nginx site conf
RUN mkdir -p /etc/nginx/ssl/
ADD ssl/nginx.crt /etc/nginx/ssl/nginx.crt
ADD ssl/nginx.key /etc/nginx/ssl/nginx.key

RUN rm -Rf /etc/nginx/conf.d/*
RUN rm -Rf /etc/nginx/sites-available/default
RUN rm -Rf /etc/nginx/sites-enabled/default

ADD conf/nginx-site.conf /etc/nginx/sites-available/default.conf
RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

# Supervisor Config
ADD conf/supervisord.conf /etc/supervisord.conf

# Start Supervisord
ADD scripts/start.sh /start.sh
RUN chmod 755 /start.sh

# Setup Volume
VOLUME ["/app"]

# change nginx directory
RUN mkdir -p /app/src/public
RUN mkdir -p /var/www/html/logs

# add test PHP file
ADD src/index.html /app/src/public/index.html
RUN chown -Rf www-data.www-data /app
RUN chown -Rf www-data.www-data /var/www/html



#PHP7


# Xdebug Remote Host IP
ENV XDEBUG_REMOTE_HOST_IP host.docker.internal

RUN LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php


RUN apt-get install -y php7.2-fpm \
    php7.2-mysql \
    php7.2-curl \
    php7.2-gd \
    php7.2-intl \
    #php7.2-mcrypt \
    php-memcache \
    php7.2-sqlite \
    php7.2-tidy \
    php7.2-xmlrpc \
    php7.2-pgsql \
    php7.2-ldap \
    freetds-common \
    php7.2-pgsql \
    php7.2-sqlite3 \
    php7.2-json \
    php7.2-xml \
    php7.2-mbstring \
    php7.2-soap \
    php7.2-zip \
    php7.2-cli \
    php7.2-sybase \
    php7.2-odbc \
    php7.2-dev


RUN apt-get install -y php-pear

RUN pecl install xdebug

# Install xdebug
#RUN wget http://xdebug.org/files/xdebug-2.4.0.tgz
#RUN tar -xvzf xdebug-2.4.0.tgz
#RUN cd xdebug-2.4.0 && phpize
#RUN cd xdebug-2.4.0 && ./configure
#RUN cd xdebug-2.4.0 && make
#RUN cd xdebug-2.4.0 && cp modules/xdebug.so /usr/lib/php/20131226


ADD conf/xdebug.conf /xdebug.conf
ADD conf/xdebug.conf /xdebug.conf

RUN cat /xdebug.conf >> /etc/php/7.2/fpm/php.ini
RUN cat /xdebug.conf >> /etc/php/7.2/cli/php.ini

#RUN rm -rf /xdebug-2.4.0
#RUN rm -rf /xdebug-2.4.0.tgz

# Cleanup
RUN apt-get remove --purge -y software-properties-common \
    python-software-properties

RUN apt-get autoremove -y
RUN apt-get clean
RUN apt-get autoclean

#tweek php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/7.2/fpm/php.ini
RUN sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php/7.2/fpm/php.ini
RUN sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php/7.2/fpm/php.ini
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.2/fpm/php-fpm.conf
RUN sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/7.2/fpm/pool.d/www.conf
RUN sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php/7.2/fpm/pool.d/www.conf
RUN sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php/7.2/fpm/pool.d/www.conf
RUN sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php/7.2/fpm/pool.d/www.conf
RUN sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php/7.2/fpm/pool.d/www.conf
RUN sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php/7.2/fpm/pool.d/www.conf
RUN sed -i -e "/listen\s*=\s*\/run\/php\/php7.2-fpm.sock/c\listen = 127.0.0.1:9100" /etc/php/7.2/fpm/pool.d/www.conf
RUN sed -i -e "/pid\s*=\s*\/run/c\pid = /run/php7.2-fpm.pid" /etc/php/7.2/fpm/php-fpm.conf

#fix ownership of sock file
RUN sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php/7.2/fpm/pool.d/www.conf
RUN find /etc/php/7.2/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# Supervisor Config
ADD conf/supervisord.conf /supervisord.conf
RUN cat /supervisord.conf >> /etc/supervisord.conf

# Start Supervisord

ADD scripts/start.sh /start.sh
RUN chmod 755 /start.sh

# Setup Volume
VOLUME ["/app"]

# add test PHP file
ADD src/index.php /app/src/public/index.php
ADD src/index.php /app/src/public/info.php
RUN chown -Rf www-data.www-data /app
RUN chown -Rf www-data.www-data /var/www/html


#install mcrypt (deprecated as a php package since 7.2) we need to use pecl
RUN apt-get -y install gcc make autoconf libc-dev pkg-config
RUN apt-get -y install php7.2-dev
RUN apt-get -y install libmcrypt-dev
RUN pecl install mcrypt-1.0.1


# Expose Ports
EXPOSE 443
EXPOSE 80
EXPOSE 9000

CMD ["/bin/bash", "/start.sh"]
