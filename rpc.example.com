# Proxy timeout settings
proxy_buffering off;
proxy_connect_timeout  360s;
proxy_send_timeout     360s;
proxy_read_timeout     700s;

# Configure proxy to retry on errors and timeouts
proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
proxy_next_upstream_timeout 200s;
proxy_next_upstream_tries 5;

# Set $connection_upgrade to 'close' if $http_upgrade is empty, otherwise 'upgrade'
map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}

# Upstream configuration for Ronin node websocket port
upstream ronin-proxy-ws {
    server 0.0.0.0:8546 weight=3 max_conns=250 max_fails=1000000 fail_timeout=30s;
    keepalive 32;
}

# Upstream configuration for Ronin node HTTP port
upstream ronin-proxy-http {
    server 0.0.0.0:8545 weight=3 max_conns=250 max_fails=1000000 fail_timeout=30s;
}

server {
    listen 80;
    listen 443 ssl;
    server_name rpc.example.com;

    # SSL configuration for Cloudflare
    ssl_certificate /etc/letsencrypt/live/rpc.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/rpc.example.com/privkey.pem;

    # Recommended SSL parameters for security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # Only allow requests from Cloudflare IPs
    # These are official Cloudflare IP ranges
    allow 103.21.244.0/22;
    allow 103.22.200.0/22;
    allow 103.31.4.0/22;
    allow 104.16.0.0/13;
    allow 104.24.0.0/14;
    allow 108.162.192.0/18;
    allow 131.0.72.0/22;
    allow 141.101.64.0/18;
    allow 162.158.0.0/15;
    allow 172.64.0.0/13;
    allow 173.245.48.0/20;
    allow 188.114.96.0/20;
    allow 190.93.240.0/20;
    allow 197.234.240.0/22;
    allow 198.41.128.0/17;
    deny all;

    # Handle common static files
    location ~ ^/(favicon.ico|robots.txt) {
        log_not_found off;
    }

    # WebSocket endpoint configuration
    location /websocket/ {
        proxy_pass http://ronin-proxy-ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_connect_timeout 60s;
        proxy_buffering off;
    }

    # Main location block handling both HTTP and WebSocket connections
    location / {
        # Check if request is WebSocket
        set $websocket 1;
        if ($http_connection !~* "upgrade") {
            set $websocket 0;
        }
        if ($http_upgrade !~* "websocket") {
            set $websocket 0;
        }

        # Route WebSocket requests to dedicated endpoint
        if ($websocket) {
            rewrite ^ /websocket$uri last;
        }

        # HTTP proxy configuration
        proxy_pass http://ronin-proxy-http;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_intercept_errors on;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }
}
