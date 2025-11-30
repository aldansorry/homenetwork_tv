# Audio Backend API - Quick Setup Guide

## Backend Server Setup (Node.js)

### 1. Create Backend Directory
```bash
mkdir audio-backend
cd audio-backend
npm init -y
npm install express archiver
```

### 2. Create server.js
```javascript
const express = require('express');
const archiver = require('archiver');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 3000;

app.get('/provide/audio', (req, res) => {
  res.setHeader('Content-Type', 'application/zip');
  res.setHeader('Content-Disposition', 'attachment; filename="audio.zip"');

  const archive = archiver('zip', { zlib: { level: 9 } });
  
  archive.on('error', (err) => {
    res.status(500).send({ error: err.message });
  });

  archive.pipe(res);
  
  const audioDir = path.join(__dirname, 'audio');
  if (fs.existsSync(audioDir)) {
    archive.directory(audioDir, 'audio');
  }

  archive.finalize();
});

app.listen(PORT, () => {
  console.log(`🎵 Server running at http://localhost:${PORT}`);
});
```

### 3. Folder Structure
```
audio-backend/
├── server.js
├── package.json
└── audio/
    ├── song1.mp3
    ├── song2.m4a
    ├── song3.wav
    └── ...
```

### 4. Run Server
```bash
node server.js
```

## Testing Backend

### Check Server Status
```bash
curl http://localhost:3000/provide/audio -O audio.zip
unzip audio.zip
ls audio/
```

## Flutter App - What Happens

1. **First Launch**
   - Check: Does audio exist in local storage? NO
   - Download: GET http://localhost:3000/provide/audio → get ZIP
   - Extract: Unzip file to app documents
   - Load: Read audio files from storage
   - Display: Show playlist

2. **Subsequent Launches**
   - Check: Does audio exist in local storage? YES
   - Skip: Download (if already cached)
   - Load: Read audio files directly
   - Display: Show playlist

## Audio Formats Supported
- ✅ MP3 (.mp3)
- ✅ M4A (.m4a)
- ✅ WAV (.wav)
- ✅ OGG (.ogg)
- ✅ WebM (.webm)
- ✅ WEBA (.weba)

## Key Features

### AudioService (lib/services/audio_service.dart)
```dart
// Download dan extract dari backend
await AudioService.downloadAndExtractAudio();

// Load audio files dari local storage
final List<String> songs = await AudioService.loadAudioFiles();

// Get directory untuk audio
final String dir = await AudioService.getAudioDirectory();

// Check apakah audio sudah di-cache
final bool isCached = await AudioService.isAudioCached();
```

### Playing Audio
```dart
// Menggunakan DeviceFileSource untuk local files
await audioPlayer.play(DeviceFileSource(filePath));
```

## Environment Variables (Optional)

Untuk production, gunakan env variables:

```dart
// lib/config/app_config.dart
class AppConfig {
  static const String backendUrl = 
    String.fromEnvironment('BACKEND_URL', 
    defaultValue: 'http://localhost:3000/provide/audio');
}
```

## Troubleshooting

### Backend tidak terkoneksi
```bash
# Test backend
curl http://localhost:3000/provide/audio

# Check port
netstat -an | grep 3000
```

### ZIP file corrupt
- Pastikan all audio files valid
- Check file permissions
- Verify ZIP integrity: `unzip -t audio.zip`

### Large ZIP files
- Consider splitting into multiple files
- Or implement chunked download
- Monitor memory usage during extraction

## Performance Tips

1. **Optimize ZIP Size**
   - Remove unnecessary metadata
   - Use highest compression level (already set)

2. **Caching Strategy**
   - Audio cached after first download
   - Clear cache: Delete app documents folder

3. **Network**
   - Add timeout handling
   - Implement retry logic (already in code)

## Logs

Check Flutter console untuk debug messages:
```
flutter run

# Expected output:
Downloading audio from http://localhost:3000/provide/audio...
Downloaded successfully. Extracting...
Extracted: audio/song1.mp3
Extracted: audio/song2.m4a
...
Audio extraction completed!
Loaded 10 audio files
```

## Next Steps

1. ✅ Setup backend server
2. ✅ Add audio files to backend
3. ✅ Run `flutter pub get`
4. ✅ Run `flutter run`
5. ✅ App akan auto-download audio

Enjoy! 🎵
