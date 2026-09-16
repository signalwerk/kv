# Use an official Node.js runtime as the base image
FROM node:20

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json to the container
COPY package*.json ./

# Install production dependencies only
RUN npm ci --omit=dev

# Copy only the application code
COPY src ./src

# Expose ports
EXPOSE 5060

# Command to start the application
CMD ["npm", "start"]
