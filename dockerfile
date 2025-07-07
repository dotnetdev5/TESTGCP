# Use official node image as base
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy project files
COPY package*.json ./
RUN npm install
COPY . .

# Build the React app
RUN npm run build

# Serve with NGINX
FROM nginx:alpine
COPY --from=0 /app/build /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
