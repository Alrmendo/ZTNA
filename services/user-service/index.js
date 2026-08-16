const express = require('express');

const app = express();

app.get('/healthz', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Simulates a compromised user-service calling order-service laterally,
// using its own pod/service-account identity — no separate credential.
app.post('/simulate/call-order', (req, res) => {
  callUpstream('http://order-service.crm.svc.cluster.local/api/orders', res);
});

// Simulates a compromised user-service calling admin-service laterally.
app.post('/simulate/call-admin', (req, res) => {
  callUpstream('http://admin-service.crm.svc.cluster.local/admin', res);
});

async function callUpstream(target, res) {
  try {
    const upstream = await fetch(target);
    const bodyText = await upstream.text();
    res.status(upstream.status);
    res.set('Content-Type', upstream.headers.get('content-type') || 'text/plain');
    res.send(bodyText);
  } catch (err) {
    res.status(502).json({ error: err.message, target });
  }
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`user-service listening on ${PORT}`);
});
