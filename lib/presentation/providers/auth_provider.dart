import 'package:flutter/material.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;

  AuthProvider({
    required AuthRepository authRepository,
    required UserRepository userRepository,
  })  : _authRepository = authRepository,
        _userRepository = userRepository;

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // For Auth actions
  /// Call once at app startup to restore session if token exists
  Future<void> tryRestoreSession() async {
    if (!_authRepository.isAuthenticated()) return;
    try {
      _currentUser = await _authRepository.getCurrentUser();
      notifyListeners();
    } catch (_) {
      // Token expired or invalid — clear it
      await _authRepository.logout();
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();
    try {
      await _authRepository.login(email: email, password: password);
      _currentUser = await _authRepository.getCurrentUser();
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
      // Auto-login after registration
      return await login(email, password);
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

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authRepository.logout();
    } catch (_) {
      // Clear locally regardless of server response
    } finally {
      _currentUser = null;
      _setLoading(false);
    }
  }

  // Get profile actions from ProfileScreen
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