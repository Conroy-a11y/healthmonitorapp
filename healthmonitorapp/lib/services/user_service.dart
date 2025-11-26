import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitality/models/user.dart';

class UserService {
  static const String _userKey = 'current_user';

  Future<User?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);

      if (userJson == null) {
        final defaultUser = _createDefaultUser();
        await saveUser(defaultUser);
        return defaultUser;
      }

      return User.fromJson(jsonDecode(userJson));
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  Future<void> saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('Error saving user: $e');
    }
  }

  Future<void> updateUser(User user) async {
    final updatedUser = user.copyWith(updatedAt: DateTime.now());
    await saveUser(updatedUser);
  }

  User _createDefaultUser() {
    final now = DateTime.now();
    return User(
      id: 'user_001',
      name: 'Sarah Johnson',
      email: 'sarah.johnson@example.com',
      dateOfBirth: DateTime(1985, 6, 15),
      createdAt: now,
      updatedAt: now,
    );
  }
}
