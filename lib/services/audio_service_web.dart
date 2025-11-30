// Web-specific implementation: uses in-memory storage and blob URLs.
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

// IndexedDB constants
const String _dbName = 'homenetwork_audio_db';
const String _storeName = 'audioFiles';

class AudioService {
  static const String backendUrl = 'http://localhost:3000/provide/audio';

  static List<String> _webAudioFiles = [];
  static Map<String, Uint8List> _webAudioData = {};
  static Map<String, String> _webAudioUrls = {};

  static bool get isWeb => true;

  static List<int>? getAudioBytes(String fileName) {
    final bytes = _webAudioData[fileName];
    return bytes == null ? null : bytes.toList();
  }

  static String? getAudioUrl(String fileName) {
    return _webAudioUrls[fileName];
  }

  static Future<String> getAudioDirectory() async {
    return 'web_audio_cache';
  }

  static Future<bool> downloadAndExtractAudio() async {
    try {
      print('Downloading audio from $backendUrl (web)...');
      final response = await http.get(Uri.parse(backendUrl)).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout - Backend server tidak merespons'),
      );

      if (response.statusCode != 200) {
        print('Failed to download audio: HTTP ${response.statusCode}');
        return false;
      }

      final archive = ZipDecoder().decodeBytes(response.bodyBytes);

      _webAudioFiles.clear();
      _webAudioData.clear();

      // Revoke old object URLs
      _webAudioUrls.forEach((_, url) {
        try {
          html.Url.revokeObjectUrl(url);
        } catch (_) {}
      });
      _webAudioUrls.clear();

      // Initialize IndexedDB and clear old entries if any
      final db = await _openDb();
      if (db != null) {
        await _clearStore(db);
      }

      for (final file in archive) {
        if (!file.isFile) continue;
        final extension = file.name.split('.').last.toLowerCase();
        if (['mp3', 'm4a', 'webm', 'weba', 'wav', 'ogg'].contains(extension)) {
          final content = file.content as List<int>;
          final u8 = Uint8List.fromList(content);
          _webAudioFiles.add(file.name);
          _webAudioData[file.name] = u8;

          // persist to IndexedDB
          if (db != null) {
            try {
              await _putToDb(db, file.name, u8);
            } catch (e) {
              print('Failed to save ${file.name} to IndexedDB: $e');
            }
          }

          // create blob url
          try {
            final blob = html.Blob([u8]);
            final url = html.Url.createObjectUrlFromBlob(blob);
            _webAudioUrls[file.name] = url;
          } catch (e) {
            print('Failed to create blob URL for ${file.name}: $e');
          }

          print('Stored (web): ${file.name} (${u8.length} bytes)');
        }
      }

      print('Audio extraction completed! Found ${_webAudioFiles.length} audio files (web)');
      return true;
    } catch (e) {
      print('Error downloading/extracting audio (web): $e');
      return false;
    }
  }

  static Future<List<String>> loadAudioFiles() async {
    // Try to load from IndexedDB if in-memory cache is empty
    if (_webAudioFiles.isEmpty) {
      final db = await _openDb();
      if (db != null) {
        try {
          final keys = await _getAllKeys(db);
          for (final key in keys) {
            final data = await _getFromDb(db, key);
            if (data != null) {
              final u8 = Uint8List.fromList(data);
              _webAudioFiles.add(key);
              _webAudioData[key] = u8;
              try {
                final blob = html.Blob([u8]);
                final url = html.Url.createObjectUrlFromBlob(blob);
                _webAudioUrls[key] = url;
              } catch (_) {}
            }
          }
          print('Loaded ${_webAudioFiles.length} audio files from IndexedDB');
        } catch (e) {
          print('Failed to load from IndexedDB: $e');
        }
      }
    }

    print('Loading ${_webAudioFiles.length} audio files from web cache');
    return _webAudioFiles;
  }

  static Future<bool> isAudioCached() async {
    // In-memory cache only lasts for page session; return true if we have files
    if (_webAudioFiles.isNotEmpty) return true;
    // Check IndexedDB
    final db = await _openDb();
    if (db == null) return false;
    try {
      final keys = await _getAllKeys(db);
      return keys.isNotEmpty;
    } catch (e) {
      print('Error checking IndexedDB cache: $e');
      return false;
    }
  }

  // ----------------- IndexedDB helpers -----------------
  static Future<idb.Database?> _openDb() async {
    try {
      final factory = idbFactoryBrowser;
      final db = await factory.open(_dbName, version: 1, onUpgradeNeeded: (e) {
        final d = e.database as idb.Database;
        if (!d.objectStoreNames.contains(_storeName)) {
          d.createObjectStore(_storeName);
        }
      });
      return db;
    } catch (e) {
      print('Failed to open IndexedDB: $e');
      return null;
    }
  }

  static Future<void> _putToDb(idb.Database db, String key, Uint8List data) async {
    final txn = db.transaction(_storeName, idb.idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    await store.put(data, key);
    await txn.completed;
  }

  static Future<List<String>> _getAllKeys(idb.Database db) async {
    final txn = db.transaction(_storeName, idb.idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    final keys = await store.getAllKeys();
    await txn.completed;
    return (keys as List).map((e) => e.toString()).toList();
  }

  static Future<List<int>?> _getFromDb(idb.Database db, String key) async {
    final txn = db.transaction(_storeName, idb.idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    final result = await store.getObject(key);
    await txn.completed;
    if (result == null) return null;
    if (result is List<int>) return result;
    if (result is Uint8List) return result.toList();
    if (result is html.Blob) {
      try {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(result);
        await reader.onLoad.first;
        final buffer = reader.result;
        if (buffer is ByteBuffer) {
          return buffer.asUint8List().toList();
        }
        return null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> _clearStore(idb.Database db) async {
    final txn = db.transaction(_storeName, idb.idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    await store.clear();
    await txn.completed;
  }
}
