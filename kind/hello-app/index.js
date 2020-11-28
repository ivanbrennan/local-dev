#!/usr/bin/env node

const express = require('express');
const app = express();
const port = process.env.APP_PORT || "8080";
const name = process.env.APP_NAME || "default";

app.get('/', (req, res) => res.send(`${name}: Hello World`));
app.listen(port, () => console.log(`Listening on port ${port}`));
