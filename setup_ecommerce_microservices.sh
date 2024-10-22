#!/bin/bash


# Frontend: http://localhost:8080
# API Gateway: http://localhost:3000
# RabbitMQ Management UI: http://localhost:15672
# Product Service: http://localhost:4000/products

# Set up directory structure
mkdir -p ecommerce/{api-gateway,frontend,product-service,order-service,db}

# Create .env file
cat <<EOF > ecommerce/.env
POSTGRES_USER=admin_postgres
POSTGRES_PASSWORD=123
POSTGRES_DB=products
RABBITMQ_DEFAULT_USER=admin_rabbit
RABBITMQ_DEFAULT_PASS=123
EOF

# Create docker-compose.yml
cat <<EOF > ecommerce/docker-compose.yml
services:
  api-gateway:
    build: ./api-gateway
    ports:
      - "3000:3000"
    environment:
      - PORT=3000
      - PRODUCTS_SERVICE_URL=http://product-service:4000
      - ORDERS_SERVICE_URL=http://order-service:5000
    depends_on:
      - product-service
      - order-service

  product-service:
    build: ./product-service
    ports:
      - "4000:4000"
    environment:
      - PORT=4000
      - DATABASE_URL=postgres://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@db:5432/\${POSTGRES_DB}
    depends_on:
      - db

  order-service:
    build: ./order-service
    ports:
      - "5000:5000"
    environment:
      - PORT=5000
      - DATABASE_URL=postgres://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@db:5432/\${POSTGRES_DB}
      - RABBITMQ_URL=amqp://\${RABBITMQ_DEFAULT_USER}:\${RABBITMQ_DEFAULT_PASS}@rabbitmq:5672
    depends_on:
      - db
      - rabbitmq
    restart: on-failure

  frontend:
    build: ./frontend
    ports:
      - "8080:3000"
    environment:
      - REACT_APP_API_URL=http://api-gateway:3000

  rabbitmq:
    image: rabbitmq:3-management
    ports:
      - "15672:15672" # RabbitMQ management UI
      - "5672:5672"
    environment:
        RABBITMQ_DEFAULT_USER: \${RABBITMQ_DEFAULT_USER}
        RABBITMQ_DEFAULT_PASS: \${RABBITMQ_DEFAULT_PASS}
    healthcheck:
        test: ["CMD-SHELL", "rabbitmqctl status"]
        interval: 10s
        timeout: 5s
        retries: 5
  db:
    image: postgres:latest
    environment:
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: \${POSTGRES_DB}
    volumes:
      - db_data:/var/lib/postgresql/data
      - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
        test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
        interval: 10s
        timeout: 5s
        retries: 5
volumes:
  db_data:
EOF

# # Create a Dockerfile for the db service
# cat <<EOF > ecommerce/db/Dockerfile
# FROM postgres:latest
# RUN apt-get update && apt-get install -y gettext-base
# COPY entrypoint.sh /docker-entrypoint-initdb.d/entrypoint.sh
# RUN chmod +x /docker-entrypoint-initdb.d/entrypoint.sh
# EOF

# Create the init.sql.template for PostgreSQL
cat <<EOF > ecommerce/db/init.sql.template
-- Create the database if it does not exist
SELECT 'CREATE DATABASE \${POSTGRES_DB}' 
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '\${POSTGRES_DB}')\\gexec

-- Terminate connections and reconnect to the database
\\c postgres

DO
\$\$
BEGIN
   IF EXISTS (SELECT FROM pg_database WHERE datname = '\${POSTGRES_DB}') THEN
      PERFORM pg_terminate_backend(pid) 
      FROM pg_stat_activity 
      WHERE datname = '\${POSTGRES_DB}' AND pid <> pg_backend_pid();
   END IF;
END
\$\$;

-- Reconnect to the database
\\c \${POSTGRES_DB}

-- Create the orders table if it does not exist
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create the products table if it does not exist
CREATE TABLE IF NOT EXISTS product_items (
    id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL
);
EOF

cat <<EOF > ecommerce/prebuild.sh
#!/bin/bash

# Ensure the .env file is sourced to access environment variables
set -a
source .env
set +a

# Use envsubst to replace variables in init.sql.template and generate init.sql
envsubst < db/init.sql.template > db/init.sql

echo "Generated init.sql with environment variables."
EOF

# # Create entrypoint.sh for the db service
# cat <<EOF > ecommerce/db/entrypoint.sh
# #!/bin/bash
# 
# # Replace placeholders with environment variables
# envsubst < /docker-entrypoint-initdb.d/init.sql.template > /docker-entrypoint-initdb.d/init.sql
# 
# # Run the original PostgreSQL entrypoint with any passed arguments
# exec docker-entrypoint.sh "\$@"
# EOF
# 
# # Make the script executable
# chmod +x ecommerce/db/entrypoint.sh


# Create Dockerfile for api-gateway
cat <<EOF > ecommerce/api-gateway/Dockerfile
FROM node:16
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "index.js"]
EOF

# Create index.js for api-gateway
cat <<EOF > ecommerce/api-gateway/index.js
const express = require('express');
const axios = require('axios');
const app = express();

const PORT = process.env.PORT || 3000;
const PRODUCTS_SERVICE_URL = process.env.PRODUCTS_SERVICE_URL;
const ORDERS_SERVICE_URL = process.env.ORDERS_SERVICE_URL;

app.use(express.json());

// Define a simple route for the root URL
app.get('/', (req, res) => {
  res.send('API Gateway is running!');
});

// Example routes to forward requests to services
app.get('/products', async (req, res) => {
  try {
    const response = await axios.get(\`\${PRODUCTS_SERVICE_URL}/products\`);
    res.json(response.data);
  } catch (error) {
    res.status(500).send('Error connecting to Product Service');
  }
});

app.get('/orders', async (req, res) => {
  try {
    const response = await axios.get(\`\${ORDERS_SERVICE_URL}/orders\`);
    res.json(response.data);
  } catch (error) {
    res.status(500).send('Error connecting to Order Service');
  }
});

app.listen(PORT, () => {
  console.log(\`API Gateway running on port \${PORT}\`);
});
EOF

# Create Dockerfile for product-service
cat <<EOF > ecommerce/product-service/Dockerfile
FROM node:16
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 4000
CMD ["node", "index.js"]
EOF

# Create index.js for product-service
cat <<EOF > ecommerce/product-service/index.js
const express = require('express');
const app = express();
const PORT = process.env.PORT || 4000;

app.use(express.json());

app.get('/product_items', (req, res) => {
  res.json([{ id: 1, name: 'Product A' }, { id: 2, name: 'Product B' }]);
});

app.listen(PORT, () => {
  console.log(\`Product Service running on port \${PORT}\`);
});
EOF

# Create Dockerfile for order-service
cat <<EOF > ecommerce/order-service/Dockerfile
FROM node:16
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 5000
RUN apt-get update && apt-get install -y wait-for-it
CMD ["wait-for-it", "rabbitmq:5672", "--", "node", "index.js"]
EOF

# Create index.js for order-service
cat <<EOF > ecommerce/order-service/index.js
const express = require('express');
const amqp = require('amqplib/callback_api');
const { Pool } = require('pg');
const app = express();
const PORT = process.env.PORT || 5000;
const RABBITMQ_URL = process.env.RABBITMQ_URL || 'amqp://\${RABBITMQ_DEFAULT_USER}:\${RABBITMQ_DEFAULT_PASS}@rabbitmq:5672';
const DATABASE_URL = process.env.DATABASE_URL;

// Set up a connection pool to PostgreSQL
const pool = new Pool({
  connectionString: DATABASE_URL,
});

app.use(express.json());

// Sample data for orders (used for in-memory examples)
let orders = [
  { id: 1, product_name: 'Product A', quantity: 2, price: 10.99, order_date: new Date() },
  { id: 2, product_name: 'Product B', quantity: 3, price: 19.99, order_date: new Date() }
];

// Endpoint to get all orders
app.get('/orders', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM orders ORDER BY order_date DESC');
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching orders:', error.message);
    res.status(500).json({ error: 'Error fetching orders' });
  }
});

// Endpoint to create a new order
app.post('/orders', async (req, res) => {
  const { product_name, quantity, price, order_date } = req.body;
  if (product_name && quantity && price) {
    try {
      // Insert the new order into the database
      const result = await pool.query(
        \`INSERT INTO orders (product_name, quantity, price, order_date)
         VALUES (\$1, \$2, \$3, \$4) RETURNING *\`,
        [product_name, quantity, price, order_date || new Date()] // Use provided order_date or default to the current date
      );

      // Also add the new order to the in-memory array for demonstration purposes
      const newOrder = result.rows[0];
      orders.push(newOrder);

      res.status(201).json(newOrder);
    } catch (error) {
      console.error('Error creating new order:', error.message);
      res.status(500).json({ error: 'Error creating new order' });
    }
  } else {
    res.status(400).json({ error: 'Invalid order data' });
  }
});

// Function to connect to RabbitMQ with retry logic
let rabbitmqConnection;

function connectToRabbitMQ() {
  amqp.connect(RABBITMQ_URL, (err, connection) => {
    if (err) {
      console.error('Error connecting to RabbitMQ, retrying in 5 seconds...', err.message);
      setTimeout(connectToRabbitMQ, 5000); // Retry after 5 seconds
    } else {
      rabbitmqConnection = connection;
      console.log('Connected to RabbitMQ');
      setupRabbitMQChannel(connection);
    }
  });
}

// Function to set up a RabbitMQ channel
function setupRabbitMQChannel(connection) {
  connection.createChannel((err, channel) => {
    if (err) {
      console.error('Error creating RabbitMQ channel:', err.message);
    } else {
      console.log('RabbitMQ channel created');

      // Example: Declare a queue to consume messages
      const queue = 'ordersQueue';
      channel.assertQueue(queue, { durable: true });

      channel.consume(queue, (msg) => {
        if (msg !== null) {
          console.log('Received message from RabbitMQ:', msg.content.toString());
          channel.ack(msg);
        }
      });

      console.log(\`Waiting for messages in queue: \${queue}\`);
    }
  });
}

// Connect to RabbitMQ
connectToRabbitMQ();

// Start the Express server
const server = app.listen(PORT, () => {
  console.log(\`Order Service running on port \${PORT}\`);
});

// Graceful shutdown
function gracefulShutdown() {
  console.log('Shutting down order-service...');

  // Close the RabbitMQ connection if it exists
  if (rabbitmqConnection) {
    rabbitmqConnection.close(() => {
      console.log('RabbitMQ connection closed.');
      process.exit(0);
    });
  } else {
    process.exit(0);
  }

  // Close the HTTP server
  server.close(() => {
    console.log('Express server closed.');
  });
}

// Handle termination signals
process.on('SIGINT', gracefulShutdown);
process.on('SIGTERM', gracefulShutdown);
EOF

# Create Dockerfile for frontend
cat <<EOF > ecommerce/frontend/Dockerfile
FROM node:16
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
EXPOSE 80
CMD ["npx", "serve", "-s", "build"]
EOF

# Create package.json for order-service
cat <<EOF > ecommerce/order-service/package.json
{
  "name": "order-service",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "amqplib": "^0.8.0",
    "pg": "^8.10.0"
  }
}
EOF

# Create package.json for product-service
cat <<EOF > ecommerce/product-service/package.json
{
  "name": "product-service",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

# Create package.json for api-gateway
cat <<EOF > ecommerce/api-gateway/package.json
{
  "name": "api-gateway",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.4.0"
  }
}
EOF

# Create package.json for frontend
cat <<EOF > ecommerce/frontend/package.json
{
  "name": "frontend",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1"
  }
}
EOF

# Create the public directory for frontend
mkdir -p ecommerce/frontend/public

# Create index.html for frontend in public folder
cat <<EOF > ecommerce/frontend/public/index.html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="E-commerce Microservices Frontend" />
    <title>E-commerce App</title>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
EOF

# Create the src directory for frontend
mkdir -p ecommerce/frontend/src

# Create index.js for frontend in src folder
cat <<EOF > ecommerce/frontend/src/index.js
import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';

ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById('root')
);
EOF

# Create App.js for frontend in src folder
cat <<EOF > ecommerce/frontend/src/App.js
import React from 'react';

function App() {
  return (
    <div>
      <h1>Welcome to the E-commerce Microservices Frontend</h1>
    </div>
  );
}

export default App;
EOF



# Feedback for the user
echo "Directory structure created and files populated."
echo "You can now navigate to the 'ecommerce' directory and run 'docker-compose up --build' to start the services."

