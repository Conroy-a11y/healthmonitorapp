import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitality/models/user.dart';

class AuthService {
  static const String _usersKey = 'registered_users';
  static const String _currentUserIdKey = 'current_user_id';
  static const String _isLoggedInKey = 'is_logged_in';

  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (e) {
      debugPrint('Error checking login status: $e');
      return false;
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      if (!isLoggedIn) return null;

      final currentUserId = prefs.getString(_currentUserIdKey);
      if (currentUserId == null) return null;

      final users = await _getAllUsers();
      return users.firstWhere(
        (user) => user.id == currentUserId,
        orElse: () => throw Exception('User not found'),
      );
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final users = await _getAllUsers();
      final user = users.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('User not found'),
      );

      final storedPassword = await _getPassword(user.id);
      if (storedPassword != password) {
        throw Exception('Invalid password');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserIdKey, user.id);
      await prefs.setBool(_isLoggedInKey, true);

      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    DateTime? dateOfBirth,
  }) async {
    try {
      final users = await _getAllUsers();

      if (users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
        throw Exception('Email already exists');
      }

      final now = DateTime.now();
      final userId = 'user_${now.millisecondsSinceEpoch}';

      final newUser = User(
        id: userId,
        name: name,
        email: email,
        dateOfBirth: dateOfBirth,
        createdAt: now,
        updatedAt: now,
      );

      users.add(newUser);
      await _saveAllUsers(users);
      await _savePassword(userId, password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserIdKey, userId);
      await prefs.setBool(_isLoggedInKey, true);

      return true;
    } catch (e) {
      debugPrint('Signup error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserIdKey);
      await prefs.setBool(_isLoggedInKey, false);
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  Future<bool> updateProfile(User user) async {
    try {
      final users = await _getAllUsers();
      final index = users.indexWhere((u) => u.id == user.id);

      if (index == -1) {
        throw Exception('User not found');
      }

      users[index] = user.copyWith(updatedAt: DateTime.now());
      await _saveAllUsers(users);

      return true;
    } catch (e) {
      debugPrint('Update profile error: $e');
      return false;
    }
  }

  Future<bool> changePassword(
      String userId, String oldPassword, String newPassword) async {
    try {
      final storedPassword = await _getPassword(userId);

      if (storedPassword != oldPassword) {
        throw Exception('Invalid old password');
      }

      await _savePassword(userId, newPassword);
      return true;
    } catch (e) {
      debugPrint('Change password error: $e');
      return false;
    }
  }

  Future<List<User>> _getAllUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey);

      if (usersJson == null) return [];

      final List<dynamic> decoded = jsonDecode(usersJson);
      return decoded
          .map((json) {
            try {
              return User.fromJson(json);
            } catch (e) {
              debugPrint('Error parsing user: $e');
              return null;
            }
          })
          .whereType<User>()
          .toList();
    } catch (e) {
      debugPrint('Error getting all users: $e');
      return [];
    }
  }

  Future<void> _saveAllUsers(List<User> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = users.map((u) => u.toJson()).toList();
      await prefs.setString(_usersKey, jsonEncode(usersJson));
    } catch (e) {
      debugPrint('Error saving users: $e');
    }
  }

  Future<void> _savePassword(String userId, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('password_$userId', password);
    } catch (e) {
      debugPrint('Error saving password: $e');
    }
  }

  Future<String> _getPassword(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('password_$userId') ?? '';
    } catch (e) {
      debugPrint('Error getting password: $e');
      return '';
    }
  }
}
