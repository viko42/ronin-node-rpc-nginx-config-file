# Ronin network Node Reverse Proxy using Cloudflare

This nginx configuration file sets up a secure reverse proxy for a Ronin node, handling both HTTP (port 8545) and WebSocket (port 8546) connections. The setup includes SSL termination and Cloudflare integration for enhanced security.

## Features

- **Dual Protocol Support**: 
  - HTTP endpoints (Port 8545)
  - WebSocket endpoints (Port 8546)
- **SSL/TLS Configuration**:
  - TLS 1.2 and 1.3 support
  - Modern cipher suite configuration
  - Let's Encrypt certificate integration
- **Security Measures**:
  - Cloudflare IP whitelist protection
  - SSL session management
  - Proxy timeout and retry configurations
- **Load Balancing**:
  - Configurable connection limits
  - Failure handling
  - Connection weight management

## Prerequisites

- Nginx server
- Let's Encrypt SSL certificates
- Cloudflare account (for DNS and IP protection)
- Running Ronin node

## Configuration Details

### Proxy Settings
- Connection timeouts: 360s for connect/send, 700s for read
- Automatic retry on errors (500, 502, 503, 504)
- Maximum 5 retry attempts
- 200s upstream timeout

### SSL Configuration
- Certificates path: `/etc/letsencrypt/live/rpc.example.com/`
- Modern cipher suite configuration
- Session cache: 10MB
- Session timeout: 1 day

### Rate Limiting
- Max connections per upstream: 250
- Fail timeout: 30 seconds
- Weight per server: 3

## Installation

1. Replace `rpc.example.com` with your domain
2. Ensure SSL certificates are in place
3. Place this configuration in your nginx sites directory (typically `/etc/nginx/sites-available/`)
4. Create a symbolic link to sites-enabled
5. Test and reload nginx

```
sudo nginx -t
sudo systemctl reload nginx
```

## Security Considerations

- Only Cloudflare IPs are allowed to access the proxy
- All other IPs are denied by default
- SSL is configured with modern security standards
- WebSocket connections are properly handled and secured

## Important Notes

- This configuration assumes Cloudflare is being used as a proxy
- The upstream servers are configured to listen on localhost (0.0.0.0)
- Modify the SSL certificate paths according to your setup
- Adjust timeout values based on your specific needs
