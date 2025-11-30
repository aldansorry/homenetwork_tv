import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import '../services/settings_service.dart';

class Movie {
  final String uuid;
  final String title;
  final String? thumbnail;
  final String? description;

  Movie({
    required this.uuid,
    required this.title,
    this.thumbnail,
    this.description,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      uuid: json['uuid'] ?? json['id'] ?? '',
      title: json['title'] ?? json['name'] ?? 'Unknown',
      thumbnail: json['thumbnail'] ?? json['poster'] ?? json['image'],
      description: json['description'] ?? json['desc'],
    );
  }
}

class MoviePage extends StatefulWidget {
  final String movieUuid;

  const MoviePage({super.key, required this.movieUuid});

  @override
  State<MoviePage> createState() => _MoviePageState();
}

class _MoviePageState extends State<MoviePage> {
  List<Movie> movies = [];
  int currentIndex = 0;
  bool isLoading = false;
  bool isAutoPlay = false;
  double _volume = 1.0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;

  @override
  void initState() {
    super.initState();
    loadMovies();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> loadMovies() async {
    setState(() {
      isLoading = true;
    });

    try {
      final backendUrl = await SettingsService.getBackendUrl();
      final response = await http
          .get(Uri.parse('$backendUrl/movie/${widget.movieUuid}/list'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timeout'),
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Check if status is success
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> data = responseData['data'];
          final List<Movie> loadedMovies = data
              .map((json) => Movie.fromJson(json))
              .toList();

          if (mounted) {
            setState(() {
              movies = loadedMovies;
              isLoading = false;
            });

            // Load first video if available
            if (loadedMovies.isNotEmpty) {
              loadVideo(0);
            }
          }
        } else {
          if (mounted) {
            setState(() {
              isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to load movies: Invalid response format'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load movies: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading movies: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> loadVideo(int index) async {
    if (index < 0 || index >= movies.length) return;

    // Dispose previous controller
    await _videoController?.dispose();

    setState(() {
      currentIndex = index;
      _isVideoInitialized = false;
      _isVideoPlaying = false;
    });

    final movie = movies[index];
    final backendUrl = await SettingsService.getBackendUrl();
    final streamUrl =
        '$backendUrl/movie/${widget.movieUuid}/stream/${movie.uuid}';

    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));

      await _videoController!.initialize();

      bool _hasTriggeredAutoNext = false;

      _videoController!.addListener(() {
        if (mounted) {
          setState(() {
            _isVideoPlaying = _videoController!.value.isPlaying;
          });

          // Auto play next when video ends
          final position = _videoController!.value.position;
          final duration = _videoController!.value.duration;

          if (duration > Duration.zero &&
              position >= duration - const Duration(milliseconds: 100) &&
              isAutoPlay &&
              !_hasTriggeredAutoNext) {
            _hasTriggeredAutoNext = true;
            // Delay to ensure video has fully ended
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted && isAutoPlay) {
                nextVideo();
              }
            });
          }
        }
      });

      // Set volume
      await _videoController!.setVolume(_volume);

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });

        // Auto play if enabled
        if (isAutoPlay) {
          await _videoController!.play();
          setState(() {
            _isVideoPlaying = true;
          });
        }
      }
    } catch (e) {
      print('Error loading video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void togglePlayPause() {
    if (_videoController == null || !_isVideoInitialized) return;

    if (_isVideoPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
  }

  Future<void> nextVideo() async {
    if (movies.isEmpty) return;

    final nextIndex = (currentIndex + 1) % movies.length;
    await loadVideo(nextIndex);
  }

  Future<void> setVolume(double volume) async {
    setState(() {
      _volume = volume;
    });
    await _videoController?.setVolume(volume);
  }

  void toggleAutoPlay() {
    setState(() {
      isAutoPlay = !isAutoPlay;
    });
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (hours > 0) {
      return '${twoDigits(hours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // Video Player Section
            if (_isVideoInitialized && _videoController != null)
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.4,
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                    // Play/Pause overlay
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: togglePlayPause,
                        child: Container(
                          color: Colors.transparent,
                          child: Center(
                            child: Icon(
                              _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                              size: 64,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (isLoading)
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.4,
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF0000),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.4,
                color: Colors.black,
                child: const Center(
                  child: Icon(
                    Icons.videocam_off,
                    size: 64,
                    color: Colors.white38,
                  ),
                ),
              ),

            // Video Info and Controls
            if (_isVideoInitialized && _videoController != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF1A1A1A),
                child: Column(
                  children: [
                    // Video Title
                    Text(
                      movies[currentIndex].title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Progress Bar
                    if (_videoController!.value.duration > Duration.zero) ...[
                      VideoProgressIndicator(
                        _videoController!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Color(0xFFFF0000),
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatDuration(_videoController!.value.position),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              formatDuration(_videoController!.value.duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Play/Pause
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: togglePlayPause,
                              borderRadius: BorderRadius.circular(24),
                              child: Icon(
                                _isVideoPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Next
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: nextVideo,
                              borderRadius: BorderRadius.circular(24),
                              child: const Icon(
                                Icons.skip_next,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Auto Play Toggle
                        Row(
                          children: [
                            const Text(
                              'Auto Play',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: isAutoPlay,
                              onChanged: (value) => toggleAutoPlay(),
                              activeColor: const Color(0xFFFF0000),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // Volume Control
                        SizedBox(
                          height: 48,
                          child: Center(
                            child: const Icon(
                              Icons.volume_down,
                              size: 20,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 48,
                          width: 100,
                          child: Center(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3.0,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                activeTrackColor: const Color(0xFFFF0000),
                                inactiveTrackColor: Colors.white24,
                                thumbColor: const Color(0xFFFF0000),
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
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 48,
                          child: Center(
                            child: const Icon(
                              Icons.volume_up,
                              size: 20,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 48,
                          child: Center(
                            child: Text(
                              '${(_volume * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Movie List
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Movies (${movies.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                            onPressed: loadMovies,
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: isLoading && movies.isEmpty
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFF0000),
                                ),
                              ),
                            )
                          : movies.isEmpty
                          ? const Center(
                              child: Text(
                                'No movies available',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 8,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.2,
                                  ),
                              itemCount: movies.length,
                              itemBuilder: (context, index) {
                                final movie = movies[index];
                                final isSelected = index == currentIndex;
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => loadVideo(index),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFFF0000)
                                            : const Color(0xFF2A2A2A),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          movie.title,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontSize: 16,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
