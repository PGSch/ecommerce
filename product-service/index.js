const express = require('express');
const app = express();
const PORT = process.env.PORT || 4000;

app.use(express.json());

app.get('/product_items', (req, res) => {
  res.json([{ id: 1, name: 'Product A' }, { id: 2, name: 'Product B' }]);
});

app.listen(PORT, () => {
  console.log(`Product Service running on port ${PORT}`);
});
