const express = require('express');

const app = express();

app.get('/healthz', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.get('/admin', (req, res) => {
  res.status(200).json({
    panel: 'admin',
    users: 42,
    revenue: 123456,
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`admin-service listening on ${PORT}`);
});
