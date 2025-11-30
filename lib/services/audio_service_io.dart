import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'settings_service.dart';
import '../constants/app_constants.dart';

class AudioService {

  static bool get isWeb => false;

  // For web-compat callers, keep a getAudioBytes that returns null on native.
  static List<int>? getAudioBytes(String fileName) => null;
  static String? getAudioUrl(String fileName) => null;

  static Future<String> getAudioDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDocDir.path}/audio');

    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    return audioDir.path;
  }

  static Future<bool> downloadAndExtractAudio() async {
    try {
      final backendUrl = await SettingsService.getBackendUrl();
      final audioUrl = '$backendUrl${AppConstants.apiEndpointProvideAudio}';
      print('Downloading audio from $audioUrl...');
      final response = await http.get(Uri.parse(audioUrl)).timeout(
        AppConstants.audioDownloadTimeout,
        onTimeout: () => throw Exception('Request timeout - Backend server tidak merespons'),
      );

      if (response.statusCode != 200) {
        print('Failed to download audio: HTTP ${response.statusCode}');
        return false;
      }

      print('Downloaded successfully. Size: ${response.bodyBytes.length} bytes');
      print('Extracting...');

      final audioDir = await getAudioDirectory();

      // Save zip temporarily
      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/audio.zip');
      await zipFile.writeAsBytes(response.bodyBytes);

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (!file.isFile) continue;

        final filePath = '$audioDir/${file.name}';
        final outputFile = File(filePath);
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(file.content as List<int>);
        print('Extracted: ${file.name}');
      }

      await zipFile.delete();
      print('Audio extraction completed!');
      return true;
    } catch (e) {
      print('Error downloading/extracting audio: $e');
      return false;
    }
  }

  static Future<List<String>> loadAudioFiles() async {
    try {
      final audioDir = await getAudioDirectory();
      final dir = Directory(audioDir);

      if (!await dir.exists()) return [];

      final List<String> audioFiles = [];
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final extension = entity.path.split('.').last.toLowerCase();
          if (AppConstants.supportedAudioFormats.contains(extension)) {
            audioFiles.add(entity.path);
          }
        }
      }

      print('Found ${audioFiles.length} native audio files');
      return audioFiles;
    } catch (e) {
      print('Error loading audio files: $e');
      return [];
    }
  }

  static Future<bool> isAudioCached() async {
    try {
      final audioDir = await getAudioDirectory();
      final dir = Directory(audioDir);
      if (!await dir.exists()) return false;

      await for (var entity in dir.list(recursive: true)) {
        if (entity is File) {
          final extension = entity.path.split('.').last.toLowerCase();
          if (AppConstants.supportedAudioFormats.contains(extension)) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      print('Error checking audio cache: $e');
      return false;
    }
  }

  static Future<bool> clearPlaylist() async {
    try {
      final audioDir = await getAudioDirectory();
      final dir = Directory(audioDir);
      
      if (!await dir.exists()) return true;

      await for (var entity in dir.list(recursive: true)) {
        if (entity is File) {
          final extension = entity.path.split('.').last.toLowerCase();
          if (AppConstants.supportedAudioFormats.contains(extension)) {
            await entity.delete();
            print('Deleted: ${entity.path}');
          }
        }
      }

      print('Playlist cleared successfully');
      return true;
    } catch (e) {
      print('Error clearing playlist: $e');
      return false;
    }
  }

  static Future<bool> deleteAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('Deleted audio file: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting audio file: $e');
      return false;
    }
  }
}
