"""
BACKEND API REQUIREMENT

Endpoint: http://localhost:3000/provide/audio
Method: GET
Response: ZIP file containing audio files

Contoh implementasi dengan Node.js + Express:

const express = require('express');
const fs = require('fs');
const archiver = require('archiver');
const path = require('path');

const app = express();

app.get('/provide/audio', (req, res) => {
  // Set response headers
  res.setHeader('Content-Type', 'application/zip');
  res.setHeader('Content-Disposition', 'attachment; filename="audio.zip"');

  // Create archive
  const archive = archiver('zip', { zlib: { level: 9 } });

  // On error
  archive.on('error', (err) => {
    res.status(500).send({ error: err.message });
  });

  // Pipe archive data to response
  archive.pipe(res);

  // Add audio files from directory
  const audioDir = path.join(__dirname, 'audio'); // Path ke folder audio Anda
  archive.directory(audioDir, false);

  // Finalize archive
  archive.finalize();
});

app.listen(3000, () => {
  console.log('Audio provider running on http://localhost:3000');
});

INSTALASI DEPENDENCIES:
npm install express archiver

STRUKTUR FOLDER:
project-root/
├── server.js
└── audio/
    ├── song1.mp3
    ├── song2.m4a
    └── ...
"""
