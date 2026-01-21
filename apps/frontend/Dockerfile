# nginx-unprivileged already runs as non-root user (uid 101)
FROM nginxinc/nginx-unprivileged:1.25-alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY index.html style.css app.js /usr/share/nginx/html/

EXPOSE 8080
