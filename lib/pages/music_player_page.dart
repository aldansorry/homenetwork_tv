import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
import '../services/audio_service.dart';
import '../constants/tv_constants.dart';
import '../constants/app_constants.dart';
import '../widgets/tv_focusable_widget.dart';

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key});

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> {
  bool isPlaying = false;
  int currentIndex = 0;
  bool isRepeat = false;
  double _volume = 0.5;
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffle = false;
  bool _isLoadingAudio = true;
  bool _isRefreshing = false;
  String _loadingMessage = 'Checking audio files...';

  List<String> songs = [];
  late AudioPlayer audioPlayer;

  @override
  void initState() {
    super.initState();
    audioPlayer = AudioPlayer();

    audioPlayer.onPlayerComplete.listen((_) {
      if (isRepeat) {
        play();
      } else {
        nextSong();
      }
    });

    audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    });

    audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    initializeAudio();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack ||
          event.logicalKey == LogicalKeyboardKey.browserBack ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        Navigator.pop(context);
        return;
      }
    }
  }

  Future<void> initializeAudio() async {
    // Check if audio is already cached
    final isAudioCached = await AudioService.isAudioCached();

    if (!isAudioCached) {
      if (mounted) {
        setState(() {
          _isLoadingAudio = true;
          _loadingMessage = 'Downloading audio files...';
        });
      }

      // Download and extract audio
      final success = await AudioService.downloadAndExtractAudio();

      if (!success) {
        if (mounted) {
          setState(() {
            _loadingMessage = 'Failed to download audio files';
            _isLoadingAudio = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _loadingMessage = 'Loading audio files...';
        });
      }
    }

    // Load audio files
    await loadSongs();

    if (mounted) {
      setState(() {
        _isLoadingAudio = false;
      });
    }
  }

  Future<void> loadSongs() async {
    final audioFiles = await AudioService.loadAudioFiles();

    if (mounted) {
      setState(() {
        songs = audioFiles;
      });
    }

    print('Loaded ${songs.length} audio files');
  }

  Future<void> refreshPlaylist() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      // Stop current playback
      await audioPlayer.stop();

      // Clear current playlist
      setState(() {
        songs = [];
        currentIndex = 0;
        isPlaying = false;
      });

      // Download fresh audio from backend
      final success = await AudioService.downloadAndExtractAudio();

      if (success) {
        // Load new songs
        await loadSongs();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Playlist refreshed successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to refresh playlist'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error refreshing playlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> deleteSong(int index) async {
    if (index < 0 || index >= songs.length) return;

    final songName = getAudioFileName(songs[index]);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text(
          'Are you sure you want to delete "$songName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final filePath = songs[index];
    final success = await AudioService.deleteAudioFile(filePath);

    if (success) {
      if (mounted) {
        // If deleting currently playing song, stop and move to next
        if (index == currentIndex) {
          await audioPlayer.stop();
          if (songs.length > 1) {
            // Move to next song or previous if last song
            final newIndex = index < songs.length - 1 ? index : index - 1;
            setState(() {
              songs.removeAt(index);
              currentIndex = newIndex.clamp(0, songs.length - 1);
              isPlaying = false;
              _currentPosition = Duration.zero;
              _duration = Duration.zero;
            });
          } else {
            // Last song, clear everything
            setState(() {
              songs.removeAt(index);
              currentIndex = 0;
              isPlaying = false;
              _currentPosition = Duration.zero;
              _duration = Duration.zero;
            });
          }
        } else {
          // Adjust currentIndex if needed
          setState(() {
            songs.removeAt(index);
            if (index < currentIndex) {
              currentIndex--;
            }
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$songName" deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete "$songName"'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> play() async {
    if (songs.isEmpty) return;

    try {
      await audioPlayer.stop();
      await Future.delayed(const Duration(milliseconds: 100));

      final currentSong = songs[currentIndex];

      if (identical(0, 0.0)) {
        // Web platform - prefer blob URL (better browser support), fallback to bytes
        try {
          final url = AudioService.getAudioUrl(currentSong);
          if (url != null) {
            await audioPlayer.play(UrlSource(url));
            print('Playing from blob URL: $currentSong');
          } else {
            final audioBytes = AudioService.getAudioBytes(currentSong);
            if (audioBytes != null) {
              await audioPlayer.play(
                BytesSource(Uint8List.fromList(audioBytes)),
              );
              print('Playing from memory bytes: $currentSong');
            } else {
              print('Audio bytes not found: $currentSong');
            }
          }
        } catch (e) {
          print('Web playback error, attempting bytes fallback: $e');
          final audioBytes = AudioService.getAudioBytes(currentSong);
          if (audioBytes != null) {
            await audioPlayer.play(BytesSource(Uint8List.fromList(audioBytes)));
          }
        }
      } else {
        // Native platform - play from local storage
        await audioPlayer.play(DeviceFileSource(currentSong));
      }

      await audioPlayer.setVolume(_volume);
      if (mounted) {
        setState(() => isPlaying = true);
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> pause() async {
    await audioPlayer.pause();
    if (mounted) {
      setState(() => isPlaying = false);
    }
  }

  Future<void> nextSong() async {
    if (songs.isEmpty) return;

    if (mounted) {
      setState(() {
        if (_isShuffle) {
          currentIndex = (currentIndex + 1) % songs.length;
        } else {
          currentIndex = (currentIndex + 1) % songs.length;
        }
      });
    }
    play();
  }

  Future<void> previousSong() async {
    if (songs.isEmpty) return;

    if (mounted) {
      setState(() {
        currentIndex = (currentIndex - 1 + songs.length) % songs.length;
      });
    }
    play();
  }

  void toggleRepeat() {
    if (mounted) {
      setState(() => isRepeat = !isRepeat);
    }
  }

  void toggleShuffle() {
    if (mounted) {
      setState(() => _isShuffle = !_isShuffle);
    }
  }

  Future<void> retryDownloadAudio() async {
    if (mounted) {
      setState(() {
        _isLoadingAudio = true;
        _loadingMessage = 'Downloading audio files...';
      });
    }

    final success = await AudioService.downloadAndExtractAudio();

    if (success) {
      if (mounted) {
        setState(() {
          _loadingMessage = 'Loading audio files...';
        });
      }
      await loadSongs();
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _loadingMessage = 'Failed to download audio files. Tap retry again.';
          _isLoadingAudio = false;
        });
      }
    }
  }

  Future<void> setVolume(double volume) async {
    if (mounted) {
      setState(() => _volume = volume);
    }
    await audioPlayer.setVolume(volume);
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String getAudioFileName(String filePath) {
    return filePath
        .split('/')
        .last
        .replaceAll(
          RegExp(r'\.(mp3|m4a|webm|weba|wav|ogg)$', caseSensitive: false),
          '',
        );
  }

  void selectSong(int index) {
    if (mounted) {
      setState(() {
        currentIndex = index;
      });
    }
    play();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAudio) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
              ),
              const SizedBox(height: 20),
              Text(
                _loadingMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (songs.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_off, size: 64, color: Colors.white38),
              const SizedBox(height: 20),
              const Text(
                "No audio files found",
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: retryDownloadAudio,
                icon: const Icon(Icons.download),
                label: const Text('Download Audio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKeyEvent,
      child: _buildMusicScaffold(),
    );
  }

  Widget _buildMusicScaffold() {
    final currentSongName = getAudioFileName(songs[currentIndex]);
    return Scaffold(
      backgroundColor: const Color(AppConstants.colorBackgroundDark),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TvConstants.tvSafeAreaPadding),
          child: Column(
            children: [
              // Header with actions
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TvConstants.tvSpacingMedium,
                  vertical: TvConstants.tvSpacingSmall,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // 🔙 Tombol Home
                        TvFocusableWidget(
                          onTap: () {
                            Navigator.pop(context); // kembali ke Home
                          },
                          child: Container(
                            padding: const EdgeInsets.all(
                              TvConstants.tvSpacingSmall,
                            ),
                            decoration: BoxDecoration(
                              color: Color(
                                TvConstants.tvFocusColor,
                              ).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.home,
                              color: Colors.white,
                              size: TvConstants.tvIconSizeLarge,
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // 🔡 Title
                        const Text(
                          'Your Library',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: TvConstants.tvFontSizeTitle,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    // 🔄 Refresh button (tetap di kanan)
                    TvFocusableWidget(
                      onTap: _isRefreshing ? null : refreshPlaylist,
                      child: Container(
                        padding: const EdgeInsets.all(
                          TvConstants.tvSpacingSmall,
                        ),
                        decoration: BoxDecoration(
                          color: Color(
                            TvConstants.tvFocusColor,
                          ).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _isRefreshing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: TvConstants.tvIconSizeLarge,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TvConstants.tvSpacingMedium),
              // Now Playing Section (YouTube Music style)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: TvConstants.tvSpacingMedium,
                ),
                padding: const EdgeInsets.all(TvConstants.tvCardPadding),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.colorCardDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Song Title
                    Text(
                      currentSongName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: TvConstants.tvFontSizeSubtitle,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: TvConstants.tvSpacingSmall),

                    // Progress Bar
                    if (_duration.inMilliseconds > 0) ...[
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4.0,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          activeTrackColor: const Color(0xFFFF0000),
                          inactiveTrackColor: Colors.white24,
                          thumbColor: const Color(0xFFFF0000),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                        ),
                        child: Slider(
                          value: _currentPosition.inMilliseconds.toDouble(),
                          max: _duration.inMilliseconds.toDouble(),
                          onChanged: (value) async {
                            await audioPlayer.seek(
                              Duration(milliseconds: value.toInt()),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatDuration(_currentPosition),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              formatDuration(_duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Player Controls: prev, play, next, shuffle, repeat, volume
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Previous
                        TvFocusableWidget(
                          onTap: previousSong,
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: previousSong,
                                borderRadius: BorderRadius.circular(32),
                                child: const Icon(
                                  Icons.skip_previous,
                                  size: TvConstants.tvIconSizeLarge,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: TvConstants.tvSpacingSmall),
                        // Play/Pause
                        TvFocusableWidget(
                          onTap: isPlaying ? pause : play,
                          child: Material(
                            color: const Color(AppConstants.colorPrimaryRed),
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: isPlaying ? pause : play,
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 80,
                                height: 80,
                                alignment: Alignment.center,
                                child: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  size: 56,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: TvConstants.tvSpacingSmall),
                        // Next
                        TvFocusableWidget(
                          onTap: nextSong,
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: nextSong,
                                borderRadius: BorderRadius.circular(32),
                                child: const Icon(
                                  Icons.skip_next,
                                  size: TvConstants.tvIconSizeLarge,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: TvConstants.tvSpacingMedium),
                        // Shuffle
                        TvFocusableWidget(
                          onTap: toggleShuffle,
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: toggleShuffle,
                                borderRadius: BorderRadius.circular(32),
                                child: Icon(
                                  Icons.shuffle,
                                  color: _isShuffle
                                      ? const Color(
                                          AppConstants.colorPrimaryRed,
                                        )
                                      : Colors.white70,
                                  size: TvConstants.tvIconSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: TvConstants.tvSpacingSmall),
                        // Repeat
                        TvFocusableWidget(
                          onTap: toggleRepeat,
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: toggleRepeat,
                                borderRadius: BorderRadius.circular(32),
                                child: Icon(
                                  isRepeat ? Icons.repeat : Icons.repeat_one,
                                  color: isRepeat
                                      ? const Color(
                                          AppConstants.colorPrimaryRed,
                                        )
                                      : Colors.white70,
                                  size: TvConstants.tvIconSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: TvConstants.tvSpacingMedium),
                        // Volume Control
                        SizedBox(
                          height: 64,
                          child: Center(
                            child: const Icon(
                              Icons.volume_down,
                              size: TvConstants.tvIconSize,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: TvConstants.tvSpacingSmall),
                        SizedBox(
                          height: 64,
                          width: 150,
                          child: Center(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4.0,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                ),
                                activeTrackColor: const Color(
                                  AppConstants.colorPrimaryRed,
                                ),
                                inactiveTrackColor: Colors.white24,
                                thumbColor: const Color(
                                  AppConstants.colorPrimaryRed,
                                ),
                              ),
                              child: Slider(
                                value: _volume,
                                min: 0.0,
                                max: 1.0,
                                onChanged: setVolume,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: TvConstants.tvSpacingSmall),
                        SizedBox(
                          height: 64,
                          child: Center(
                            child: const Icon(
                              Icons.volume_up,
                              size: TvConstants.tvIconSize,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: TvConstants.tvSpacingSmall),
                        SizedBox(
                          height: 64,
                          child: Center(
                            child: Text(
                              '${(_volume * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: TvConstants.tvFontSizeSmall,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TvConstants.tvSpacingMedium),
              // Playlist Section
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: TvConstants.tvSpacingMedium,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.colorCardDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(
                          TvConstants.tvCardPadding,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Playlist (${songs.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: TvConstants.tvFontSizeSubtitle,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(
                            bottom: TvConstants.tvCardPadding,
                          ),
                          itemCount: songs.length,
                          itemBuilder: (context, index) {
                            bool isSelected = index == currentIndex;
                            final fileName = getAudioFileName(songs[index]);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: TvConstants.tvSpacingMedium,
                                vertical: TvConstants.tvSpacingSmall,
                              ),
                              child: TvFocusableWidget(
                                onTap: () => selectSong(index),
                                child: Container(
                                  padding: const EdgeInsets.all(
                                    TvConstants.tvSpacingMedium,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(
                                            AppConstants.colorPrimaryRed,
                                          ).withOpacity(0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(
                                                  AppConstants.colorPrimaryRed,
                                                )
                                              : const Color(
                                                  AppConstants
                                                      .colorSecondaryDark,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          isSelected
                                              ? Icons.equalizer
                                              : Icons.music_note,
                                          color: Colors.white,
                                          size: TvConstants.tvIconSize,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: TvConstants.tvSpacingMedium,
                                      ),
                                      Expanded(
                                        child: Text(
                                          fileName,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontSize:
                                                TvConstants.tvFontSizeBody,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected)
                                        const Padding(
                                          padding: EdgeInsets.only(
                                            right: TvConstants.tvSpacingSmall,
                                          ),
                                          child: Icon(
                                            Icons.volume_up,
                                            color: Color(
                                              AppConstants.colorPrimaryRed,
                                            ),
                                            size: TvConstants.tvIconSize,
                                          ),
                                        ),
                                      TvFocusableWidget(
                                        onTap: () => deleteSong(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(
                                            TvConstants.tvSpacingSmall,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.white70,
                                            size: TvConstants.tvIconSize,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: TvConstants.tvSpacingMedium),
            ],
          ),
        ),
      ),
    );
  }
}
