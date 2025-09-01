const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  const secretValue = process.env.MY_SECRET || 'No secret found';
  res.send(`Hello from SOPS example! Secret value: ${secretValue}`);
});

app.listen(port, () => {
  console.log(`App listening on port ${port}`);
});