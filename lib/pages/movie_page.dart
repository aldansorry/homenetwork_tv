import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// IMPORT FILE LAIN TETAP
import '../services/settings_service.dart';
import '../models/movie_model.dart';
import '../constants/app_constants.dart';
import '../constants/tv_constants.dart';
import '../utils/api_response_parser.dart';
import '../utils/date_time_utils.dart';
import '../widgets/tv_focusable_widget.dart';

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

  // MEDIA KIT PLAYER
  late final Player _player;
  late final VideoController _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;

  bool _isFullscreen = false;
  bool _showFullscreenControls = true;
  Timer? _fullscreenControlsTimer;

  final List<FocusNode> _gridFocusNodes = [];
  final ScrollController _gridScrollController = ScrollController();
  int _focusedGridIndex = 0;

  bool _initialLoad = true;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
_player.stream.completed.listen((completed) {
    if (!mounted) return;
    if (completed && _movieList.isNotEmpty) {
      _playNextVideo(); // ini akan panggil _loadVideo(next, autoplay: true)
    }
  });
    _loadMovieList();
  }

  @override
  void dispose() {
    _player.dispose();
    _fullscreenControlsTimer?.cancel();
    for (var node in _gridFocusNodes) {
      node.dispose();
    }
    _gridScrollController.dispose();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    super.dispose();
  }

  Future<void> _loadMovieList() async {
    if (!mounted) return;

    setState(() => _isLoadingMovies = true);

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
        final data = ApiResponseParser.parseJson(response.body);
        if (data != null) {
          final parsedMovies = ApiResponseParser.parseListResponse<MovieModel>(
            responseData: data,
            fromJson: MovieModel.fromJson,
          );

          if (parsedMovies != null) {
            setState(() {
              _movieList = parsedMovies;
              _isLoadingMovies = false;
            });

            _initializeGridFocusNodes();

            if (_movieList.isNotEmpty) {
              await _loadVideo(0, autoplay: false);
            }

            return;
          }
        }
      }

      _showError('Failed to load movies');
    } catch (e) {
      _showError('Error loading movies: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _isLoadingMovies = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _initializeGridFocusNodes() {
    // Bersihkan node lama
    for (var node in _gridFocusNodes) {
      node.dispose();
    }
    _gridFocusNodes.clear();

    // Buat focus node untuk setiap movie
    for (int i = 0; i < _movieList.length; i++) {
      _gridFocusNodes.add(FocusNode());
    }

    // Fokuskan item pertama setelah build
    if (_gridFocusNodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _gridFocusNodes[0].requestFocus();
        }
      });
    }
  }

  Future<void> _loadVideo(int index, {bool autoplay = true}) async {
    if (index < 0 || index >= _movieList.length) return;

    setState(() {
      _currentMovieIndex = index;
      _isVideoInitialized = false;
    });

    final backendUrl = await SettingsService.getBackendUrl();
    final movie = _movieList[index];

    final streamUrl =
        '$backendUrl${AppConstants.apiEndpointMovie}/${widget.movieSeriesUuid}${AppConstants.apiEndpointMovieStream}/${movie.uuid}';

    try {
      // OPEN TANPA AUTOPLAY DULU
      await _player.open(Media(streamUrl), play: false);

      // LISTENER READY STREAM
      _player.stream.buffering.where((b) => b == false).first.then((_) async {
  if (autoplay) {
    await _player.play();
  }

        await _player.setVolume(_volumeLevel * 100);

        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
            _isVideoPlaying = autoplay;
          });
        }
      });
    } catch (e) {
      _showError("Error loading video: $e");
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final pos = await _player.state.position;
    await _player.seek(pos + Duration(seconds: seconds));
    _showFullscreenControlsAndReset();
  }

  Future<void> _playNextVideo() async {
    if (_movieList.isEmpty) return;

    final next = (_currentMovieIndex + 1) % _movieList.length;
    await _loadVideo(next, autoplay: true);
  }

  void _togglePlayPause() {
    if (_isVideoPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
    setState(() {
      _isVideoPlaying = !_isVideoPlaying;
    });
  }

  Future<void> _updateVolume(double v) async {
    setState(() => _volumeLevel = v);
    await _player.setVolume(v * 100);
  }

  // ---------------- FULLSCREEN -----------------

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
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      _fullscreenControlsTimer?.cancel();
    }
  }

  void _startFullscreenControlsTimer() {
    _fullscreenControlsTimer?.cancel();
    _fullscreenControlsTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showFullscreenControls = false);
      }
    });
  }

  void _showFullscreenControlsAndReset() {
    if (!_isFullscreen) return;
    setState(() => _showFullscreenControls = true);
    _startFullscreenControlsTimer();
  }

  // ---------------- UI SECTION BELOW (UNCHANGED) -----------------

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen && _isVideoInitialized) {
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
              children: [Expanded(child: _buildMovieListSection())],
            ),
          ),
        ),
      ),
    );
  }

  // FULLSCREEN VIEW WITH media_kit VIDEO WIDGET
  Widget _buildFullscreenView() {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _seekRelative(-10);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _seekRelative(10);
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            _togglePlayPause();
          } else if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
            _toggleFullscreen();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video
            Center(child: Video(controller: _videoController)),
          ],
        ),
      ),
    );
  }

  // YOU CAN KEEP ALL YOUR UI CONTROLS — ONLY VIDEO WIDGET CHANGED
  Widget _buildFullscreenControls() {
    return Container(
      color: Colors.black38,
      child: Column(
        children: [
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
                    onPressed: _toggleFullscreen,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      child: Column(
        children: [
          // progress bar
          StreamBuilder<Duration>(
            stream: _player.streams.position,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final dur = _player.state.duration;
              return Column(
                children: [
                  LinearProgressIndicator(
                    value: dur.inMilliseconds == 0
                        ? 0
                        : pos.inMilliseconds / dur.inMilliseconds,
                    color: const Color(AppConstants.colorPrimaryRed),
                    backgroundColor: Colors.white24,
                    minHeight: 4,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                onTap: _togglePlayPause,
              ),
              const SizedBox(width: 20),
              _buildControlButton(icon: Icons.skip_next, onTap: _playNextVideo),
              const SizedBox(width: 20),
              _buildControlButton(
                icon: Icons.fullscreen_exit,
                onTap: _toggleFullscreen,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 48,
      height: 48,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Icon(icon, color: Colors.white, size: 36),
      ),
    );
  }

  // GRID / LIST SECTION — TIDAK DIUBAH

  /// BUILD LIST / GRID — MASIH PERSIS SAMA
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
            _buildListHeader(),
            Expanded(child: _buildMovieListContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
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
    );
  }

  Widget _buildMovieListContent() {
    if (_isLoadingMovies && _movieList.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(
            Color(AppConstants.colorPrimaryRed),
          ),
        ),
      );
    }
    if (_movieList.isEmpty) {
      return const Center(
        child: Text(
          "No movies available",
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
      itemBuilder: (ctx, i) {
        final m = _movieList[i];
        return _buildMovieCard(m, i, i == _currentMovieIndex);
      },
    );
  }

  Widget _buildMovieCard(MovieModel movie, int index, bool isSelected) {
    return TvFocusableWidget(
      focusNode: index < _gridFocusNodes.length ? _gridFocusNodes[index] : null,
      onTap: () async {
        await _loadVideo(index);
        _player.play();
        _toggleFullscreen();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(AppConstants.colorPrimaryRed)
              : const Color(AppConstants.colorSecondaryDark),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              movie.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleGridKeyEvent(KeyEvent event) {
    // kode fokus anda tetap
  }
}
