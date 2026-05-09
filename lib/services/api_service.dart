import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Change this to your backend URL
  // static const String baseUrl = 'http://LTP-083:5000/api';
  static const String baseUrl =
      'https://materialmanagement-backend-q3f4.onrender.com/api';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, String>? params}) async {
    try {
      final headers = await getHeaders();
      var uri = Uri.parse('$baseUrl$endpoint');
      if (params != null) {
        uri = uri.replace(queryParameters: params);
      }
      final response = await http.get(uri, headers: headers);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final headers = await getHeaders();
      final response =
          await http.delete(Uri.parse('$baseUrl$endpoint'), headers: headers);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // Server returned non-JSON (e.g. HTML error page)
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body ?? {'success': true};
    }

    final msg = body?['message'];
    if (msg != null && msg.toString().isNotEmpty) {
      return {'success': false, 'message': msg.toString()};
    }
    return {
      'success': false,
      'message': _statusMessage(response.statusCode),
    };
  }

  static String _statusMessage(int code) {
    switch (code) {
      case 400: return 'Bad request. Please check your input.';
      case 401: return 'Session expired. Please log in again.';
      case 403: return 'You do not have permission for this action.';
      case 404: return 'Resource not found.';
      case 409: return 'A record with these details already exists.';
      case 422: return 'Invalid data submitted.';
      case 500: return 'Server error. Please try again later.';
      case 502:
      case 503: return 'Service temporarily unavailable. Please try again.';
      default:  return 'Request failed (HTTP $code).';
    }
  }
}
