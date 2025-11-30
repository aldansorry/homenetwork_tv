const express = require('express');
const fs = require('fs');
const archiver = require('archiver');
const path = require('path');

const app = express();
const PORT = 3000;

// Endpoint untuk menyediakan audio files sebagai zip
app.get('/provide/audio', (req, res) => {
  try {
    // Set response headers untuk download zip
    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', 'attachment; filename="audio.zip"');

    // Create archiver instance
    const archive = archiver('zip', { 
      zlib: { level: 9 } 
    });

    // Handle error
    archive.on('error', (err) => {
      console.error('Archive error:', err);
      res.status(500).send({ error: err.message });
    });

    // Pipe archive data ke response
    archive.pipe(res);

    // Add all audio files dari directory
    const audioDir = path.join(__dirname, 'audio');
    
    if (fs.existsSync(audioDir)) {
      archive.directory(audioDir, 'audio');
    } else {
      console.warn('Audio directory not found:', audioDir);
    }

    // Finalize the archive
    archive.finalize();

    console.log(`Audio files downloaded at ${new Date().toISOString()}`);
  } catch (error) {
    console.error('Error in /provide/audio:', error);
    res.status(500).json({ error: 'Failed to provide audio files' });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Audio server is running' });
});

app.listen(PORT, () => {
  console.log(`🎵 Audio provider server running at http://localhost:${PORT}`);
  console.log(`📁 Audio files directory: ${path.join(__dirname, 'audio')}`);
});
