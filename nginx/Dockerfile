# Using a compact OS
FROM alpine:3.2

MAINTAINER Pan Jiabang <panjiabang@gmail.com> 

# Install Nginx
RUN apk --update add nginx && rm -rf /var/cache/apk/*

# Copy blog source

ADD ./dockerize /usr/local/bin/
COPY nginx.conf /etc/nginx/nginx.conf
COPY sites/* /etc/nginx/sites-enabled/

EXPOSE 80

# Start Nginx and with dockerize
CMD ["dockerize", "-stdout", "/var/log/nginx/access.log", "-stderr", "/var/log/nginx/error.log", "nginx" , "-g", "daemon off;"]
