FROM nginx:stable-alpine

# Create client hosting point
RUN mkdir -p /var/www/client

# Load built client
ADD client/build /var/www/client

# Bootstrap configuration
COPY nginx.conf /etc/nginx/
