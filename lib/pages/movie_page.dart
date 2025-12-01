import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../services/settings_service.dart';
import '../models/movie_model.dart';
import '../constants/app_constants.dart';
import '../constants/tv_constants.dart';
import '../utils/api_response_parser.dart';
import '../utils/date_time_utils.dart';
import '../widgets/tv_focusable_widget.dart';

/// Page for playing movies/episodes from a series
class MoviePage extends StatefulWidget {
  final String movieSeriesUuid;

  const MoviePage({super.key, required this.movieSeriesUuid});

  @override
  State<MoviePage> createState() => _MoviePageState();
}

class _MoviePageState extends State<MoviePage> {
  List<MovieModel> _movieList = [];
  int _currentMovieIndex = 0;
  bool _isLoadingMovies = false;
  bool _isAutoPlayEnabled = true;
  double _volumeLevel = AppConstants.defaultVolume;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;
  bool _isFullscreen = false;
  bool _showFullscreenControls = true;
  Timer? _fullscreenControlsTimer;
  final List<FocusNode> _gridFocusNodes = [];
  final ScrollController _gridScrollController = ScrollController();
  int _focusedGridIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMovieList();
  }

  @override
  void dispose() {
    // Cancel timer
    _fullscreenControlsTimer?.cancel();
    _gridScrollController.dispose();
    // Dispose focus nodes
    for (var node in _gridFocusNodes) {
      node.dispose();
    }
    // Reset system UI when disposing
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _videoController?.dispose();
    super.dispose();
  }

  void _initializeGridFocusNodes() {
    for (var node in _gridFocusNodes) {
      node.dispose();
    }
    _gridFocusNodes.clear();
    for (int i = 0; i < _movieList.length; i++) {
      _gridFocusNodes.add(FocusNode());
    }
    if (_gridFocusNodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _gridFocusNodes[0].requestFocus();
      });
    }
  }

  void _handleGridKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && _movieList.isNotEmpty) {
      final gridColumns = TvConstants.tvGridCrossAxisCount;
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowRight:
          if (_focusedGridIndex < _movieList.length - 1) {
            setState(() {
              _focusedGridIndex++;
            });
            _gridFocusNodes[_focusedGridIndex].requestFocus();
            _scrollToGridItem(_focusedGridIndex);
          }
          break;
        case LogicalKeyboardKey.arrowLeft:
          if (_focusedGridIndex > 0) {
            setState(() {
              _focusedGridIndex--;
            });
            _gridFocusNodes[_focusedGridIndex].requestFocus();
            _scrollToGridItem(_focusedGridIndex);
          }
          break;
        case LogicalKeyboardKey.arrowDown:
          final nextIndex = _focusedGridIndex + gridColumns;
          if (nextIndex < _movieList.length) {
            setState(() {
              _focusedGridIndex = nextIndex;
            });
            _gridFocusNodes[_focusedGridIndex].requestFocus();
            _scrollToGridItem(_focusedGridIndex);
          }
          break;
        case LogicalKeyboardKey.arrowUp:
          final prevIndex = _focusedGridIndex - gridColumns;
          if (prevIndex >= 0) {
            setState(() {
              _focusedGridIndex = prevIndex;
            });
            _gridFocusNodes[_focusedGridIndex].requestFocus();
            _scrollToGridItem(_focusedGridIndex);
          }
          break;
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.enter:
          _loadVideo(_focusedGridIndex);
          break;
        default:
          break;
      }
    }
  }

  Future<void> _seekRelative(int seconds) async {
    if (_videoController == null || !_isVideoInitialized) return;

    final current = _videoController!.value.position;
    final duration = _videoController!.value.duration;

    Duration target = current + Duration(seconds: seconds);

    // clamp supaya tidak keluar batas
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;

    await _videoController!.seekTo(target);

    // Tampilkan control sebentar
    _showFullscreenControlsAndReset();
  }

  /// Load list of movies/episodes from API
  Future<void> _loadMovieList() async {
    if (!mounted) return;

    setState(() {
      _isLoadingMovies = true;
    });

    try {
      final backendUrl = await SettingsService.getBackendUrl();
      final apiUrl =
          '$backendUrl${AppConstants.apiEndpointMovie}/${widget.movieSeriesUuid}${AppConstants.apiEndpointMovieList}';

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(
            AppConstants.networkTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );

      if (response.statusCode == 200) {
        final responseData = ApiResponseParser.parseJson(response.body);
        if (responseData != null) {
          final parsedMovies = ApiResponseParser.parseListResponse<MovieModel>(
            responseData: responseData,
            fromJson: MovieModel.fromJson,
          );

          if (parsedMovies != null && mounted) {
            setState(() {
              _movieList = parsedMovies;
              _isLoadingMovies = false;
            });

            _initializeGridFocusNodes();

            // Load first video if available
            if (parsedMovies.isNotEmpty) {
              _loadVideo(0);
            }
            return;
          }
        }
      }

      _handleError('Failed to load movies: ${response.statusCode}');
    } catch (error) {
      _handleError('Error loading movies: $error');
    }
  }

  /// Handle errors with user feedback
  void _handleError(String errorMessage) {
    if (!mounted) return;

    setState(() {
      _isLoadingMovies = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
    );
  }

  /// Load and initialize video player for selected movie
  Future<void> _loadVideo(int movieIndex) async {
    if (movieIndex < 0 || movieIndex >= _movieList.length) return;

    // Dispose previous controller
    await _videoController?.dispose();

    if (!mounted) return;

    setState(() {
      _currentMovieIndex = movieIndex;
      _isVideoInitialized = false;
      _isVideoPlaying = false;
    });

    final selectedMovie = _movieList[movieIndex];
    final backendUrl = await SettingsService.getBackendUrl();
    final streamUrl =
        '$backendUrl${AppConstants.apiEndpointMovie}/${widget.movieSeriesUuid}${AppConstants.apiEndpointMovieStream}/${selectedMovie.uuid}';

    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      await _videoController!.initialize();

      bool hasTriggeredAutoNext = false;

      _videoController!.addListener(() {
        if (!mounted) return;

        final isPlaying = _videoController!.value.isPlaying;
        if (isPlaying != _isVideoPlaying) {
          setState(() {
            _isVideoPlaying = _videoController!.value.isPlaying;
          });
        }

        // Auto play next when video ends
        final position = _videoController!.value.position;
        final duration = _videoController!.value.duration;

        if (duration > Duration.zero &&
            position >= duration - const Duration(milliseconds: 100) &&
            _isAutoPlayEnabled &&
            !hasTriggeredAutoNext) {
          hasTriggeredAutoNext = true;
          Future.delayed(AppConstants.autoNextDelay, () {
            if (mounted && _isAutoPlayEnabled) {
              _playNextVideo();
            }
          });
        }
      });

      // Set volume
      await _videoController!.setVolume(_volumeLevel);

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });

        // Auto play if enabled
        if (_isAutoPlayEnabled) {
          await _videoController!.play();
          setState(() {
            _isVideoPlaying = true;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Toggle play/pause state
  void _togglePlayPause() {
    if (_videoController == null || !_isVideoInitialized) return;

    if (_isVideoPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
  }

  /// Play next video in the list
  Future<void> _playNextVideo() async {
    if (_movieList.isEmpty) return;

    final nextIndex = (_currentMovieIndex + 1) % _movieList.length;
    await _loadVideo(nextIndex);
  }

  /// Toggle auto play feature
  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlayEnabled = !_isAutoPlayEnabled;
    });
  }

  /// Update volume level
  Future<void> _updateVolume(double volume) async {
    if (mounted) {
      setState(() {
        _volumeLevel = volume;
      });
    }
    await _videoController?.setVolume(volume);
  }

  /// Toggle fullscreen mode
  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      _showFullscreenControls = true;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _startFullscreenControlsTimer();
    } else {
      _fullscreenControlsTimer?.cancel();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  /// Start timer to hide fullscreen controls after inactivity
  void _startFullscreenControlsTimer() {
    _fullscreenControlsTimer?.cancel();
    _fullscreenControlsTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isFullscreen) {
        setState(() {
          _showFullscreenControls = false;
        });
      }
    });
  }

  /// Show fullscreen controls and reset timer
  void _showFullscreenControlsAndReset() {
    if (!_isFullscreen) return;

    setState(() {
      _showFullscreenControls = true;
    });
    _startFullscreenControlsTimer();
  }

  void _scrollToGridItem(int index) {
    final itemExtent = 275.0; // tinggi + spacing movie card, sesuaikan
    final offset = (index ~/ TvConstants.tvGridCrossAxisCount) * itemExtent;

    _gridScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen && _isVideoInitialized && _videoController != null) {
      return _buildFullscreenView();
    }

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleGridKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(AppConstants.colorBackgroundDark),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(TvConstants.tvSafeAreaPadding),
            child: Column(
              children: [
                _buildVideoPlayerSection(),
                if (_isVideoInitialized && _videoController != null)
                  _buildVideoControlsSection(),
                const SizedBox(height: TvConstants.tvSpacingLarge),
                Expanded(child: _buildMovieListSection()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build fullscreen video view
  Widget _buildFullscreenView() {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _seekRelative(-10); // rewind
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _seekRelative(10); // forward
          }
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            _togglePlayPause();
          }
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            _toggleFullscreen();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Fullscreen video player
            Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),
            // Controls overlay with auto-hide
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _showFullscreenControlsAndReset();
                  _togglePlayPause();
                },
                onPanUpdate: (_) => _showFullscreenControlsAndReset(),
                onPanStart: (_) => _showFullscreenControlsAndReset(),
                onPanEnd: (_) => _showFullscreenControlsAndReset(),
                child: AnimatedOpacity(
                  opacity: _showFullscreenControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        // Top controls
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _movieList[_currentMovieIndex].title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.fullscreen_exit,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  onPressed: () {
                                    _showFullscreenControlsAndReset();
                                    _toggleFullscreen();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Bottom controls
                        SafeArea(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Column(
                              children: [
                                // Progress bar
                                if (_videoController!.value.duration >
                                    Duration.zero) ...[
                                  GestureDetector(
                                    onTap: _showFullscreenControlsAndReset,
                                    child: VideoProgressIndicator(
                                      _videoController!,
                                      allowScrubbing: true,
                                      colors: const VideoProgressColors(
                                        playedColor: Color(
                                          AppConstants.colorPrimaryRed,
                                        ),
                                        bufferedColor: Colors.white24,
                                        backgroundColor: Colors.white12,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateTimeUtils.formatDuration(
                                            _videoController!.value.position,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          DateTimeUtils.formatDuration(
                                            _videoController!.value.duration,
                                          ),
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
                                // Control buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildControlButton(
                                      icon: _isVideoPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      onTap: () {
                                        _showFullscreenControlsAndReset();
                                        _togglePlayPause();
                                      },
                                    ),
                                    const SizedBox(width: 16),
                                    _buildControlButton(
                                      icon: Icons.skip_next,
                                      onTap: () {
                                        _showFullscreenControlsAndReset();
                                        _playNextVideo();
                                      },
                                    ),
                                    const SizedBox(width: 16),
                                    _buildControlButton(
                                      icon: _isFullscreen
                                          ? Icons.fullscreen_exit
                                          : Icons.fullscreen,
                                      onTap: () {
                                        _showFullscreenControlsAndReset();
                                        _toggleFullscreen();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build video player widget
  Widget _buildVideoPlayerSection() {
    if (_isVideoInitialized && _videoController != null) {
      return Container(
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
                onTap: _togglePlayPause,
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
      );
    }

    if (_isLoadingMovies) {
      return Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.4,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Color(AppConstants.colorPrimaryRed),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.4,
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.videocam_off, size: 64, color: Colors.white38),
      ),
    );
  }

  /// Build video controls section
  Widget _buildVideoControlsSection() {
    final currentMovie = _movieList[_currentMovieIndex];

    return Container(
      padding: const EdgeInsets.all(TvConstants.tvCardPadding),
      color: const Color(AppConstants.colorCardDark),
      child: Column(
        children: [
          // Video Title
          Text(
            currentMovie.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: TvConstants.tvFontSizeSubtitle,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: TvConstants.tvSpacingSmall),

          // Progress Bar
          if (_videoController!.value.duration > Duration.zero) ...[
            VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(AppConstants.colorPrimaryRed),
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
                    DateTimeUtils.formatDuration(
                      _videoController!.value.position,
                    ),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    DateTimeUtils.formatDuration(
                      _videoController!.value.duration,
                    ),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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
              _buildControlButton(
                icon: _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                onTap: _togglePlayPause,
              ),
              const SizedBox(width: 8),
              _buildControlButton(icon: Icons.skip_next, onTap: _playNextVideo),
              const SizedBox(width: 8),
              _buildControlButton(
                icon: Icons.fullscreen,
                onTap: _toggleFullscreen,
              ),
              const SizedBox(width: 16),
              // Auto Play Toggle
              Row(
                children: [
                  const Text(
                    'Auto Play',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isAutoPlayEnabled,
                    onChanged: (_) => _toggleAutoPlay(),
                    activeColor: const Color(AppConstants.colorPrimaryRed),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              _buildVolumeControl(),
            ],
          ),
        ],
      ),
    );
  }

  /// Build control button widget
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Icon(icon, size: 36, color: Colors.white),
        ),
      ),
    );
  }

  /// Build volume control widget
  Widget _buildVolumeControl() {
    return Row(
      children: [
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
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: const Color(AppConstants.colorPrimaryRed),
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(AppConstants.colorPrimaryRed),
              ),
              child: Slider(
                value: _volumeLevel,
                min: 0.0,
                max: 1.0,
                onChanged: _updateVolume,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 48,
          child: Center(
            child: const Icon(Icons.volume_up, size: 20, color: Colors.white70),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 48,
          child: Center(
            child: Text(
              '${(_volumeLevel * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  /// Build movie list section
  Widget _buildMovieListSection() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(AppConstants.colorCardDark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(TvConstants.tvCardPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Movies (${_movieList.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: TvConstants.tvFontSizeSubtitle,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TvFocusableWidget(
                    onTap: _loadMovieList,
                    child: Container(
                      padding: const EdgeInsets.all(TvConstants.tvSpacingSmall),
                      decoration: BoxDecoration(
                        color: Color(TvConstants.tvFocusColor).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: TvConstants.tvIconSizeLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildMovieListContent()),
          ],
        ),
      ),
    );
  }

  /// Build movie list content
  Widget _buildMovieListContent() {
    if (_isLoadingMovies && _movieList.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Color(AppConstants.colorPrimaryRed),
          ),
        ),
      );
    }

    if (_movieList.isEmpty) {
      return const Center(
        child: Text(
          'No movies available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return GridView.builder(
      controller: _gridScrollController,
      padding: const EdgeInsets.all(TvConstants.tvCardPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: TvConstants.tvGridCrossAxisCount,
        crossAxisSpacing: TvConstants.tvGridSpacing,
        mainAxisSpacing: TvConstants.tvGridSpacing,
        childAspectRatio: TvConstants.tvGridAspectRatio,
      ),
      itemCount: _movieList.length,
      itemBuilder: (context, index) {
        final movie = _movieList[index];
        final isSelected = index == _currentMovieIndex;
        return _buildMovieCard(movie, index, isSelected);
      },
    );
  }

  /// Build individual movie card
  Widget _buildMovieCard(MovieModel movie, int index, bool isSelected) {
    return TvFocusableWidget(
      focusNode: index < _gridFocusNodes.length ? _gridFocusNodes[index] : null,
      autofocus: index == 0,
      onTap: () => _loadVideo(index),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(AppConstants.colorPrimaryRed)
              : const Color(AppConstants.colorSecondaryDark),
          borderRadius: BorderRadius.circular(8),
          border: _gridFocusNodes[index].hasFocus
              ? Border.all(
                  color: Color(TvConstants.tvFocusColor),
                  width: TvConstants.tvFocusBorderWidth,
                )
              : null,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(TvConstants.tvSpacingSmall),
            child: Text(
              movie.title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: TvConstants.tvFontSizeBody,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
