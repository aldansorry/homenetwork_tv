# Audio Service Implementation - Local Storage & Backend

## Overview
Aplikasi musik player telah diperbarui untuk mengambil audio files dari backend server melalui HTTP request dan menyimpannya di local storage device.

## Alur Kerja

### 1. **Inisialisasi (App Start)**
   - App akan mengecek apakah audio sudah di-cache di local storage
   - Jika belum ada → Download file ZIP dari backend
   - Unzip file ZIP ke local storage
   - Load audio files dari local storage

### 2. **Backend Endpoint**
   - **URL**: `http://localhost:3000/provide/audio`
   - **Method**: GET
   - **Response**: ZIP file containing audio files
   - **Status Code**: 200 untuk success

### 3. **Local Storage Location**
   - **Android**: `/data/data/com.example.homenetwork_tv/app_flutter/audio/`
   - **iOS**: `Documents/audio/`
   - **Web**: Browser local storage
   - **Windows/Mac/Linux**: Application Documents folder

## File Structure

```
lib/
├── main.dart
├── pages/
│   ├── main_menu.dart
│   ├── home_page.dart
│   ├── movie_page.dart
│   └── music_player_page.dart
├── services/
│   └── audio_service.dart          ← NEW: Audio management service
└── widgets/
```

## Dependencies Added

```yaml
dependencies:
  http: ^1.2.0                       # HTTP client untuk download
  path_provider: ^2.1.0              # Local storage path access
  archive: ^3.6.0                    # ZIP file handling
```

## Audio Service Methods

### `getAudioDirectory()`
- Mendapatkan path directory untuk menyimpan audio
- Auto-create directory jika belum ada
- Returns: `Future<String>`

### `downloadAndExtractAudio()`
- Download ZIP file dari backend
- Unzip ke local storage
- Delete temporary ZIP file
- Returns: `Future<bool>` (success/failed)

### `loadAudioFiles()`
- Scan directory untuk audio files
- Support format: `.mp3`, `.m4a`, `.webm`, `.weba`, `.wav`, `.ogg`
- Returns: `Future<List<String>>`

### `isAudioCached()`
- Check apakah audio sudah ada di local storage
- Avoid redundant downloads
- Returns: `Future<bool>`

## MusicPlayerPage Updates

### Loading States
- **Checking**: Cek apakah audio sudah di-cache
- **Downloading**: Download file dari backend
- **Extracting**: Unzip file
- **Loading**: Load files ke memory
- **Ready**: Siap untuk digunakan

### UI Changes
- Progress indicator selama loading
- Error handling dengan retry button
- Display file names dari local storage

### Audio Playback
- Menggunakan `DeviceFileSource` untuk local files
- Bukan lagi menggunakan `AssetSource`

## Setup Backend Server

### Node.js + Express (Recommended)

1. **Install Dependencies**
```bash
npm init -y
npm install express archiver
```

2. **Create server.js** (lihat `example_backend_server.js`)

3. **Folder Structure**
```
backend-server/
├── server.js
└── audio/
    ├── song1.mp3
    ├── song2.m4a
    └── ...
```

4. **Run Server**
```bash
node server.js
```

Server akan berjalan di `http://localhost:3000`

## Testing

### 1. Test Backend
```bash
curl -O http://localhost:3000/provide/audio
```

### 2. Test Health Check
```bash
curl http://localhost:3000/health
```

### 3. Test Flutter App
- Ensure backend server is running
- `flutter run`
- App akan otomatis download dan extract audio

## Error Handling

- Download timeout: Retry dengan button
- Invalid ZIP: Display error message
- Network error: Show "Failed to download" message
- No audio files: Display "No audio files found" message

## Security Notes

⚠️ **Development Only**: 
- Backend URL hardcoded ke `localhost:3000`
- Untuk production, gunakan environment variables atau config file

## Future Enhancements

- [ ] Add progress indicator untuk download
- [ ] Pause/Resume download support
- [ ] Update audio files (clear old & download new)
- [ ] Custom backend URL configuration
- [ ] Error retry with exponential backoff
- [ ] Offline mode detection

## Troubleshooting

### Issue: "Undefined name 'AssetManifest'"
**Solution**: Import sudah dihapus, menggunakan local storage method

### Issue: Download timeout
**Solution**: Increase timeout di AudioService atau optimize ZIP file size

### Issue: Cannot find app documents directory
**Solution**: Ensure `path_provider` plugin properly initialized

### Issue: Permission denied on local storage
**Solution**: Check AndroidManifest.xml & Info.plist permissions

## References

- [path_provider documentation](https://pub.dev/packages/path_provider)
- [http package](https://pub.dev/packages/http)
- [archive package](https://pub.dev/packages/archive)
- [audioplayers documentation](https://pub.dev/packages/audioplayers)
