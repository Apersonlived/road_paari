import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../data/api/api_exception.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/user_repository.dart';
import '../services/notification_service.dart';
import '../services/proximity_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final ProximityService _proximityService;

  AuthProvider({
    required AuthRepository authRepository,
    required UserRepository userRepository,
    required ProximityService proximityService,
  }) : _authRepository = authRepository,
       _userRepository = userRepository,
       _proximityService = proximityService;

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> tryRestoreSession() async {
    if (!_authRepository.isAuthenticated()) return;
    try {
      _currentUser = await _authRepository.getCurrentUser();
      notifyListeners();
      await _saveFcmToken(); // also save token on session restore
      _proximityService.start();
    } catch (_) {
      await _authRepository.logout();
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();
    try {
      await _authRepository.login(email: email, password: password);
      _currentUser = await _authRepository.getCurrentUser();
      await _saveFcmToken();
      _proximityService.start();
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Login failed. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String? fullName) async {
    _setLoading(true);
    _clearError();
    try {
      await _authRepository.register(
        email: email,
        password: password,
        fullName: fullName,
      );
      return await login(email, password); // login() calls _saveFcmToken()
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Registration failed. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  // Single definition of _saveFcmToken
  Future<void> _saveFcmToken() async {
    try {
      String? token = NotificationService.instance.fcmToken;
      token ??= await FirebaseMessaging.instance.getToken();
      debugPrint('=== Saving FCM token: $token ===');
      if (token == null) return;
      await _authRepository.saveFcmToken(token);
      debugPrint('=== FCM token saved successfully ===');
    } catch (e) {
      debugPrint('=== Failed to save FCM token: $e ===');
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authRepository.logout();
      _proximityService.stop();
    } catch (_) {
    } finally {
      _currentUser = null;
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({String? fullName, String? email}) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _clearError();
    try {
      final updated = await _userRepository.updateUser(
        userId: _currentUser!.id,
        fullName: fullName,
        email: email,
      );
      _currentUser = updated;
      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to update profile.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _clearError();
    try {
      await _userRepository.deleteUser(_currentUser!.id);
      await _authRepository.logout();
      _proximityService.stop();
      _currentUser = null;
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (_) {
      _setError('Failed to delete account.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _clearError();
    try {
      await _userRepository.changePassword(
        userId: _currentUser!.id,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to change password.');
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
