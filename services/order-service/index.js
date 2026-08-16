const express = require('express');

const app = express();

app.get('/healthz', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.get('/api/orders', (req, res) => {
  res.status(200).json({
    orders: [
      { id: 1, item: 'Widget', qty: 3 },
      { id: 2, item: 'Gadget', qty: 1 },
    ],
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`order-service listening on ${PORT}`);
});
