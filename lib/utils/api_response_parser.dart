import 'dart:convert';

/// Utility class for parsing API responses
class ApiResponseParser {
  ApiResponseParser._(); // Private constructor to prevent instantiation

  /// Parse standard API response with status and data
  /// Returns null if response is invalid
  static List<T>? parseListResponse<T>({
    required Map<String, dynamic> responseData,
    required T Function(Map<String, dynamic>) fromJson,
    String statusKey = 'status',
    String dataKey = 'data',
    String successStatus = 'success',
  }) {
    if (responseData[statusKey] == successStatus &&
        responseData[dataKey] != null) {
      final List<dynamic> dataList = responseData[dataKey];
      return dataList.map((json) => fromJson(json as Map<String, dynamic>)).toList();
    }
    return null;
  }

  /// Parse JSON string to Map
  static Map<String, dynamic>? parseJson(String jsonString) {
    try {
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}

