import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/settings_service.dart';
import '../models/movie_series_model.dart';
import '../constants/app_constants.dart';
import '../utils/api_response_parser.dart';
import 'movie_page.dart';

/// Page displaying list of movie series
class MovieListPage extends StatefulWidget {
  const MovieListPage({super.key});

  @override
  State<MovieListPage> createState() => _MovieListPageState();
}

class _MovieListPageState extends State<MovieListPage> {
  List<MovieSeriesModel> _movieSeriesList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMovieSeries();
  }

  /// Load movie series list from API
  Future<void> _loadMovieSeries() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final backendUrl = await SettingsService.getBackendUrl();
      final apiUrl = '$backendUrl${AppConstants.apiEndpointMovie}';

      final response = await http.get(Uri.parse(apiUrl)).timeout(
            AppConstants.networkTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );

      if (response.statusCode == 200) {
        final responseData = ApiResponseParser.parseJson(response.body);
        if (responseData != null) {
          final parsedSeries = ApiResponseParser.parseListResponse<MovieSeriesModel>(
            responseData: responseData,
            fromJson: MovieSeriesModel.fromJson,
          );

          if (parsedSeries != null && mounted) {
            setState(() {
              _movieSeriesList = parsedSeries;
              _isLoading = false;
            });
            return;
          }
        }
      }

      _handleError('Failed to load movie series: ${response.statusCode}');
    } catch (error) {
      _handleError('Error loading movie series: $error');
    }
  }

  /// Handle errors with user feedback
  void _handleError(String errorMessage) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Navigate to movie page with selected series UUID
  void _navigateToMoviePage(String seriesUuid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoviePage(movieSeriesUuid: seriesUuid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.colorBackgroundDark),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildMovieSeriesList(),
          ],
        ),
      ),
    );
  }

  /// Build header section
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Movie Series',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadMovieSeries,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  /// Build movie series list
  Widget _buildMovieSeriesList() {
    return Expanded(
      child: _isLoading && _movieSeriesList.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(AppConstants.colorPrimaryRed),
                ),
              ),
            )
          : _movieSeriesList.isEmpty
              ? const Center(
                  child: Text(
                    'No movie series available',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _movieSeriesList.length,
                  itemBuilder: (context, index) {
                    final series = _movieSeriesList[index];
                    return _buildSeriesBanner(series);
                  },
                ),
    );
  }

  /// Build individual series banner
  Widget _buildSeriesBanner(MovieSeriesModel series) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToMoviePage(series.uuid),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(AppConstants.colorCardDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(series),
                  _buildGradientOverlay(),
                  _buildTitle(series),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build thumbnail or placeholder
  Widget _buildThumbnail(MovieSeriesModel series) {
    if (series.thumbnail != null && series.thumbnail!.isNotEmpty) {
      return Image.network(
        series.thumbnail!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(series.title);
        },
      );
    }
    return _buildPlaceholder(series.title);
  }

  /// Build placeholder when thumbnail is not available
  Widget _buildPlaceholder(String title) {
    return Container(
      color: const Color(AppConstants.colorSecondaryDark),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.movie,
              size: 64,
              color: Colors.white38,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Build gradient overlay for better text readability
  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
    );
  }

  /// Build title overlay
  Widget _buildTitle(MovieSeriesModel series) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Text(
        series.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(0, 2),
              blurRadius: 4,
              color: Colors.black87,
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
