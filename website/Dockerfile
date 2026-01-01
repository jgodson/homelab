FROM node:20-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:1.27-alpine

RUN printf '%s\n' \
  'server {' \
  '  listen 8080;' \
  '  server_name _;' \
  '' \
  '  root /usr/share/nginx/html;' \
  '  index index.html;' \
  '' \
  '  location / {' \
  '    try_files $uri $uri/ =404;' \
  '  }' \
  '' \
  '  error_page 404 /404/index.html;' \
  '' \
  '  location = /404/index.html {' \
  '    internal;' \
  '  }' \
  '}' \
  > /etc/nginx/conf.d/default.conf && \
  sed -i '/user  nginx;/d' /etc/nginx/nginx.conf && \
  chown -R 10001:10001 /var/cache/nginx && \
  chown -R 10001:10001 /var/log/nginx && \
  chown -R 10001:10001 /etc/nginx/conf.d && \
  touch /var/run/nginx.pid && \
  chown 10001:10001 /var/run/nginx.pid
COPY --from=build /app/dist/ /usr/share/nginx/html/

USER 10001

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
