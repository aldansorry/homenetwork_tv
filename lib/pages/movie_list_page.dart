import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'movie_page.dart';
import '../services/settings_service.dart';

class MovieSeries {
  final String uuid;
  final String title;
  final String? thumbnail;
  final String? description;

  MovieSeries({
    required this.uuid,
    required this.title,
    this.thumbnail,
    this.description,
  });

  factory MovieSeries.fromJson(Map<String, dynamic> json) {
    return MovieSeries(
      uuid: json['uuid'] ?? json['id'] ?? '',
      title: json['title'] ?? json['name'] ?? 'Unknown',
      thumbnail: json['thumbnail'] ?? json['poster'] ?? json['image'],
      description: json['description'] ?? json['desc'],
    );
  }
}

class MovieListPage extends StatefulWidget {
  const MovieListPage({super.key});

  @override
  State<MovieListPage> createState() => _MovieListPageState();
}

class _MovieListPageState extends State<MovieListPage> {
  List<MovieSeries> movieSeries = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadMovieSeries();
  }

  Future<void> loadMovieSeries() async {
    setState(() {
      isLoading = true;
    });

    try {
      final backendUrl = await SettingsService.getBackendUrl();
      final response = await http
          .get(Uri.parse('$backendUrl/movie'))
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
          final List<MovieSeries> loadedSeries = data
              .map((json) => MovieSeries.fromJson(json))
              .toList();

          if (mounted) {
            setState(() {
              movieSeries = loadedSeries;
              isLoading = false;
            });
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
      print('Error loading movie series: $e');
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

  void navigateToMoviePage(String uuid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoviePage(movieUuid: uuid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
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
                    onPressed: loadMovieSeries,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),

            // Movie Series List
            Expanded(
              child: isLoading && movieSeries.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF0000),
                        ),
                      ),
                    )
                  : movieSeries.isEmpty
                      ? const Center(
                          child: Text(
                            'No movie series available',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: movieSeries.length,
                          itemBuilder: (context, index) {
                            final series = movieSeries[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => navigateToMoviePage(series.uuid),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A1A),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Thumbnail or Placeholder
                                          series.thumbnail != null &&
                                                  series.thumbnail!.isNotEmpty
                                              ? Image.network(
                                                  series.thumbnail!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (context, error, stackTrace) {
                                                    return _buildPlaceholder(
                                                        series.title);
                                                  },
                                                )
                                              : _buildPlaceholder(series.title),
                                          // Gradient overlay
                                          Container(
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
                                          ),
                                          // Title
                                          Positioned(
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
                                          ),
                                        ],
                                      ),
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
    );
  }

  Widget _buildPlaceholder(String title) {
    return Container(
      color: const Color(0xFF2A2A2A),
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
}

