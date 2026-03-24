# Stage 1: Build the Flutter web application
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# Copy pubspec and get dependencies
COPY pubspec.* ./
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Build the web application
RUN flutter build web --release

# Stage 2: Serve via Nginx
FROM nginx:alpine

# Copy built web assets to Nginx static HTML folder
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose standard port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
