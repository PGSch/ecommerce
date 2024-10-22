const express = require('express');
const amqp = require('amqplib/callback_api');
const { Pool } = require('pg');
const app = express();
const PORT = process.env.PORT || 5000;
const RABBITMQ_URL = process.env.RABBITMQ_URL || 'amqp://${RABBITMQ_DEFAULT_USER}:${RABBITMQ_DEFAULT_PASS}@rabbitmq:5672';
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
        `INSERT INTO orders (product_name, quantity, price, order_date)
         VALUES ($1, $2, $3, $4) RETURNING *`,
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

      console.log(`Waiting for messages in queue: ${queue}`);
    }
  });
}

// Connect to RabbitMQ
connectToRabbitMQ();

// Start the Express server
const server = app.listen(PORT, () => {
  console.log(`Order Service running on port ${PORT}`);
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
