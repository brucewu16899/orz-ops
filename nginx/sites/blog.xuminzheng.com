server {
    listen 5000;
    server_name blog.xuminzheng.com;
    port_in_redirect off;
    location / {
        proxy_pass http://blog-jeromewarran1129.app.cnpaas.io/;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

upstream backend_blog_xuminzheng_com {
    #ip_hash;
    server 127.0.0.1:5000;
}

server {
    listen 80;
    server_name blog.xuminzheng.com;
    location / {
        proxy_next_upstream http_502 http_503 http_504 http_404 error timeout invalid_header;
        proxy_pass http://backend_blog_xuminzheng_com;
        proxy_redirect off;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
    }
}
