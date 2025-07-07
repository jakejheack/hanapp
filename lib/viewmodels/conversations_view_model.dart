import 'package:flutter/material.dart';
import 'package:hanapp/models/conversation.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/listing_service.dart';

class ConversationsViewModel extends ChangeNotifier {
  final ListingService _listingService = ListingService();
  User? _currentUser;
  List<Conversation> _conversations = [];
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchConversations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _currentUser = await AuthService.getUser();
    if (_currentUser == null) {
      _errorMessage = 'User not logged in.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    final response = await _listingService.getConversations(userId: _currentUser!.id);

    if (response['success']) {
      _conversations = response['conversations'].cast<Conversation>();
    } else {
      _errorMessage = response['message'] ?? 'Failed to load conversations.';
    }
    _isLoading = false;
    notifyListeners();
  }
}