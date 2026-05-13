import 'package:flutter/material.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';

class UserProvider with ChangeNotifier {
  final UserRepository _userRepository;

  UserProvider({required UserRepository userRepository})
      : _userRepository = userRepository;

  List<User> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<User> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAllUsers() async {
    _setLoading(true);
    _clearError();
    try {
      _users = await _userRepository.getAllUsers();
      _setLoading(false);
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
    } catch (_) {
      _setError('Failed to load users.');
      _setLoading(false);
    }
  }

  Future<bool> deleteUser(int userId) async {
    _clearError();
    try {
      await _userRepository.deleteUser(userId);
      _users.removeWhere((u) => u.id == userId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Failed to delete user.');
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void _clearError() => _errorMessage = null;
}