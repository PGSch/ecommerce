FROM node:16
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 5000
RUN apt-get update && apt-get install -y wait-for-it
CMD ["wait-for-it", "rabbitmq:5672", "--", "node", "index.js"]
