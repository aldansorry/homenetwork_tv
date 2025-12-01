/// Application-wide constants
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // API Endpoints
  static const String apiEndpointMovie = '/movie';
  static const String apiEndpointMovieList = '/list';
  static const String apiEndpointMovieStream = '/stream';
  static const String apiEndpointProvideAudio = '/provide/audio';
  static const String apiEndpointDownloaderYoutube = '/downloader/youtube';

  // Settings Keys
  static const String settingsKeyBackendUrl = 'backend_url';
  static const String defaultBackendUrl = 'http://localhost:3000';

  // Timeouts
  static const Duration networkTimeout = Duration(seconds: 10);
  static const Duration audioDownloadTimeout = Duration(seconds: 30);
  static const Duration autoNextDelay = Duration(milliseconds: 200);

  // UI Constants
  static const double defaultVolume = 1.0;
  static const double defaultMusicVolume = 0.5;
  static const int gridCrossAxisCount = 8;
  static const double gridSpacing = 12.0;
  static const double gridAspectRatio = 1.2;

  // Colors
  static const int colorPrimaryRed = 0xFFFF0000;
  static const int colorBackgroundDark = 0xFF0A0A0A;
  static const int colorCardDark = 0xFF1A1A1A;
  static const int colorSecondaryDark = 0xFF2A2A2A;
  
  // TV-specific constants (exported from TvConstants for convenience)
  static const int tvColorFocus = 0xFFFF0000;

  // Audio Formats
  static const List<String> supportedAudioFormats = [
    'mp3',
    'm4a',
    'webm',
    'weba',
    'wav',
    'ogg',
  ];

  // IndexedDB Constants (Web)
  static const String indexedDbName = 'homenetwork_audio_db';
  static const String indexedDbStoreName = 'audioFiles';
}

