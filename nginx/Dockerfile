FROM alpine:3.2

MAINTAINER Pan Jiabang <panjiabang@gmail.com> 

# Install Nginx From Source
ENV NGINX_VERSION nginx-1.8.0

RUN mkdir -p /tmp/src && \
    cd /tmp/src && \
    apk update && \
    apk add openssl pcre zlib && \
    wget https://github.com/gnosek/nginx-upstream-fair/archive/master.zip && \
    unzip master.zip && \
    apk add openssl-dev pcre-dev zlib-dev build-base && \
    wget http://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxvf ${NGINX_VERSION}.tar.gz && \
    cd /tmp/src/${NGINX_VERSION} && \
    ./configure \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --add-module=/tmp/src/nginx-upstream-fair-master \
        --prefix=/etc/nginx \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --sbin-path=/usr/local/sbin/nginx && \
    make && \
    make install && \
    apk del build-base openssl-dev pcre-dev zlib-dev && \
    rm -rf /tmp/src && \
    rm -rf /var/cache/apk/*

# Copy Config
COPY nginx.conf /etc/nginx/nginx.conf
COPY sites/* /etc/nginx/sites-enabled/

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 443

# Start Nginx and with dockerize
CMD ["nginx", "-g", "daemon off;"]
