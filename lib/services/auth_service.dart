import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  bool isLoggedIn = false;
  bool isLoading = true;
  Map<String, dynamic>? currentUser;

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      final res = await ApiService.get('/auth/me');
      if (res['success'] == true) {
        currentUser = res['data'];
        isLoggedIn = true;
      } else {
        await prefs.remove('token');
      }
    }
    isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String userId, String password) async {
    final res = await ApiService.post('/auth/login', {
      'userId': userId,
      'password': password,
    });
    if (res['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', res['token']);
      currentUser = res['user'];
      isLoggedIn = true;
      notifyListeners();
    }
    return res;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    isLoggedIn = false;
    currentUser = null;
    notifyListeners();
  }

  bool get isAdmin => currentUser?['role'] == 'admin';
  String get userName => currentUser?['name'] ?? 'User';
  String get userRole => currentUser?['role'] ?? 'user';

  List<String> get allowedScreens {
    if (isAdmin) return const [];  // admin bypasses checks
    final perms = currentUser?['userCategory']?['permissions'];
    if (perms is List) return List<String>.from(perms);
    return const [];  // no category → no access
  }

  bool canAccess(String key) {
    if (isAdmin) return true;
    return allowedScreens.contains(key);
  }
}
