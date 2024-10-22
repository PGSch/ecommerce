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
    const response = await axios.get(`${PRODUCTS_SERVICE_URL}/products`);
    res.json(response.data);
  } catch (error) {
    res.status(500).send('Error connecting to Product Service');
  }
});

app.get('/orders', async (req, res) => {
  try {
    const response = await axios.get(`${ORDERS_SERVICE_URL}/orders`);
    res.json(response.data);
  } catch (error) {
    res.status(500).send('Error connecting to Order Service');
  }
});

app.listen(PORT, () => {
  console.log(`API Gateway running on port ${PORT}`);
});
