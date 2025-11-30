import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
import '../services/audio_service.dart';

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
      setState(() => _currentPosition = position);
    });

    audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });

    initializeAudio();
  }

  Future<void> initializeAudio() async {
    // Check if audio is already cached
    final isAudioCached = await AudioService.isAudioCached();
    
    if (!isAudioCached) {
      setState(() {
        _isLoadingAudio = true;
        _loadingMessage = 'Downloading audio files...';
      });
      
      // Download and extract audio
      final success = await AudioService.downloadAndExtractAudio();
      
      if (!success) {
        setState(() {
          _loadingMessage = 'Failed to download audio files';
          _isLoadingAudio = false;
        });
        return;
      }
      
      setState(() {
        _loadingMessage = 'Loading audio files...';
      });
    }
    
    // Load audio files
    await loadSongs();
    
    setState(() {
      _isLoadingAudio = false;
    });
  }

  Future<void> loadSongs() async {
    final audioFiles = await AudioService.loadAudioFiles();
    
    setState(() {
      songs = audioFiles;
    });
    
    print('Loaded ${songs.length} audio files');
  }

  Future<void> play() async {
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
              await audioPlayer.play(BytesSource(Uint8List.fromList(audioBytes)));
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
      setState(() => isPlaying = true);
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> pause() async {
    await audioPlayer.pause();
    setState(() => isPlaying = false);
  }

  Future<void> nextSong() async {
    setState(() {
      if (_isShuffle) {
        currentIndex = (currentIndex + 1) % songs.length;
      } else {
        currentIndex = (currentIndex + 1) % songs.length;
      }
    });
    play();
  }

  Future<void> previousSong() async {
    setState(() {
      currentIndex = (currentIndex - 1 + songs.length) % songs.length;
    });
    play();
  }

  void toggleRepeat() => setState(() => isRepeat = !isRepeat);

  void toggleShuffle() => setState(() => _isShuffle = !_isShuffle);

  Future<void> retryDownloadAudio() async {
    setState(() {
      _isLoadingAudio = true;
      _loadingMessage = 'Downloading audio files...';
    });

    final success = await AudioService.downloadAndExtractAudio();

    if (success) {
      setState(() {
        _loadingMessage = 'Loading audio files...';
      });
      await loadSongs();
      setState(() {
        _isLoadingAudio = false;
      });
    } else {
      setState(() {
        _loadingMessage = 'Failed to download audio files. Tap retry again.';
        _isLoadingAudio = false;
      });
    }
  }

  Future<void> setVolume(double volume) async {
    setState(() => _volume = volume);
    await audioPlayer.setVolume(volume);
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String getAudioFileName(String filePath) {
    return filePath.split('/').last;
  }

  void selectSong(int index) {
    setState(() {
      currentIndex = index;
    });
    play();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAudio) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_loadingMessage),
            ],
          ),
        ),
      );
    }

    if (songs.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_off, size: 64, color: Colors.grey),
              const SizedBox(height: 20),
              const Text("No audio files found"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: retryDownloadAudio,
                child: const Text('Download Audio'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('Playlist', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  bool isSelected = index == currentIndex;
                  final fileName = getAudioFileName(songs[index]);
                  return ListTile(
                    leading: Icon(Icons.music_note, color: isSelected ? Colors.blue : Colors.grey),
                    title: Text(fileName),
                    tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
                    onTap: () => selectSong(index),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            const Text('Now Playing:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(getAudioFileName(songs[currentIndex]), 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Progress bar
            if (_duration.inMilliseconds > 0)
              Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: _currentPosition.inMilliseconds.toDouble(),
                      max: _duration.inMilliseconds.toDouble(),
                      onChanged: (value) async {
                        await audioPlayer.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDuration(_currentPosition), style: const TextStyle(fontSize: 12)),
                        Text(formatDuration(_duration), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 15),

            // Volume control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.volume_mute, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          ),
                          child: Slider(
                            value: _volume,
                            min: 0.0,
                            max: 1.0,
                            onChanged: setVolume,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.volume_up, size: 20),
                      const SizedBox(width: 10),
                      Text('${(_volume * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Player controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 40),
                  onPressed: previousSong,
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause_circle : Icons.play_circle, 
                    size: 60,
                    color: Colors.blue,
                  ),
                  onPressed: isPlaying ? pause : play,
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 40),
                  onPressed: nextSong,
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Additional actions
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    size: 32,
                    color: _isShuffle ? Colors.blue : Colors.grey,
                  ),
                  onPressed: toggleShuffle,
                  tooltip: 'Shuffle',
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: Icon(
                    Icons.repeat,
                    size: 32,
                    color: isRepeat ? Colors.blue : Colors.grey,
                  ),
                  onPressed: toggleRepeat,
                  tooltip: 'Repeat',
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
