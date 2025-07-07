import 'package:flutter/material.dart';
import 'package:hanapp/models/message.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/listing_service.dart';
import 'package:hanapp/utils/word_filter_service.dart';

class ChatViewModel extends ChangeNotifier {
  final ListingService _listingService = ListingService();
  final AuthService _authService = AuthService();
  User? _currentUser;
  User? _recipientUser;
  String? _recipientName;
  int? _recipientId;
  int? _listingId;
  String? _listingTitle;
  int? _applicationId;
  bool _isLister = false;
  String _applicationStatus = 'pending';

  List<Message> _messages = [];
  bool _isLoadingMessages = true;
  bool _isSendingMessage = false;

  bool _showListerConfirmButton = false;
  bool get showListerConfirmButton => _showListerConfirmButton;

  User? get currentUser => _currentUser;
  User? get recipientUser => _recipientUser;
  String? get recipientName => _recipientName;
  int? get recipientId => _recipientId;
  int? get listingId => _listingId;
  String? get listingTitle => _listingTitle;
  int? get applicationId => _applicationId;
  bool get isLister => _isLister;
  String get applicationStatus => _applicationStatus;
  List<Message> get messages => _messages;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSendingMessage => _isSendingMessage;

  Future<void> initializeChat(Map<String, dynamic> args) async {
    print('ChatViewModel: initializeChat called with args: $args');
    _currentUser = await AuthService.getUser();
    _recipientName = args['recipientName'];
    _recipientId = args['recipientId'];
    _listingId = args['listingId'];
    _listingTitle = args['listingTitle'];
    _applicationId = args['applicationId'];
    _isLister = args['isLister'] ?? false;

    print('ChatViewModel: After initialization:');
    print('  _currentUser ID: ${_currentUser?.id}');
    print('  _currentUser Role: ${_currentUser?.role}');
    print('  _recipientId: $_recipientId');
    print('  _listingId: $_listingId');
    print('  _listingTitle: $_listingTitle');
    print('  _applicationId: $_applicationId');
    print('  _isLister (from args): $_isLister');

    if (_currentUser != null && _recipientId != null) {
      await _fetchRecipientProfile();
      await fetchMessages();
    } else {
      _isLoadingMessages = false;
      notifyListeners();
      print('ChatViewModel: Initialization failed: currentUser or recipientId is null.');
    }
  }

  Future<void> _fetchRecipientProfile() async {
    if (_recipientId == null) return;
    print('ChatViewModel: Fetching recipient profile for ID: $_recipientId');
    final response = await _authService.getUserProfileById(userId: _recipientId!);
    if (response['success']) {
      _recipientUser = response['user'];
      print('ChatViewModel: Recipient profile fetched: ${_recipientUser?.fullName}');
    } else {
      print('ChatViewModel: Failed to fetch recipient profile: ${response['message']}');
    }
    notifyListeners();
  }

  Future<void> fetchMessages() async {
    if (_currentUser == null || _recipientId == null) {
      print('ChatViewModel: _currentUser or _recipientId is null. Cannot fetch messages.');
      _isLoadingMessages = false;
      notifyListeners();
      return;
    }

    _isLoadingMessages = true;
    notifyListeners();

    print('ChatViewModel: Attempting to fetch messages for user1Id: ${_currentUser!.id}, user2Id: $_recipientId, listingId: $_listingId');

    final response = await _listingService.getMessages(
      user1Id: _currentUser!.id,
      user2Id: _recipientId!,
      listingId: _listingId,
    );

    _isLoadingMessages = false;
    if (response['success']) {
      _messages = response['messages'].cast<Message>();
      print('ChatViewModel: Successfully loaded messages: ${_messages.length} messages.');
      _inferApplicationStatusFromMessages();
    } else {
      print('ChatViewModel: Failed to load messages: ${response['message']}');
    }
    notifyListeners();
  }

  void _inferApplicationStatusFromMessages() {
    _showListerConfirmButton = false;
    bool ongoingMessageFound = false;
    bool markedDoneByDoerMessageFound = false;
    bool confirmedDoneMessageFound = false;

    // for (var msg in _messages.reversed) {
    //   // Robust checks for system messages
    //   if (msg.messageText.contains('confirmed the completion of the project')) {
    //     confirmedDoneMessageFound = true;
    //     break;
    //   }
    //   // Check for two distinct parts of the "marked as done" message
    //   if (msg.messageText.contains('marked the project') && msg.messageText.contains('as done. Please confirm.')) {
    //     markedDoneByDoerMessageFound = true;
    //   }
    //   if (msg.messageText.contains('started the project')) {
    //     ongoingMessageFound = true;
    //   }
    // }

    if (confirmedDoneMessageFound) {
      _applicationStatus = 'completed';
    } else if (markedDoneByDoerMessageFound) {
      _applicationStatus = 'completed_by_doer';
      if (_isLister) {
        _showListerConfirmButton = true;
      }
    } else if (ongoingMessageFound) {
      _applicationStatus = 'ongoing';
    } else {
      _applicationStatus = 'pending';
    }
    print('ChatViewModel: Inferred application status: $_applicationStatus');
    print('ChatViewModel: showListerConfirmButton: $_showListerConfirmButton (isLister: $_isLister)');
  }

  Future<Map<String, dynamic>> sendMessage(String messageText) async {
    if (messageText.trim().isEmpty || _currentUser == null || _recipientId == null) {
      print('ChatViewModel: Cannot send message: text empty or user/recipient null.');
      return {'success': false, 'message': 'Cannot send message: text empty or user/recipient null.'};
    }

    // Check for banned words in the message content
    print('ChatViewModel: Checking message for banned words: "$messageText"');
    final bannedWords = await WordFilterService().findBannedWords(messageText.trim());
    
    if (bannedWords.isNotEmpty) {
      print('ChatViewModel: Banned words detected in message');
      return {
        'success': false, 
        'message': 'Message contains inappropriate content',
        'bannedWords': bannedWords['text'] ?? []
      };
    }

    _isSendingMessage = true;
    notifyListeners();

    final response = await _listingService.sendMessage(
      senderId: _currentUser!.id,
      receiverId: _recipientId!,
      messageText: messageText.trim(),
      listingId: _listingId,
    );

    _isSendingMessage = false;
    if (response['success']) {
      print('ChatViewModel: Message sent successfully.');
      await fetchMessages();
      return {'success': true, 'message': 'Message sent successfully.'};
    } else {
      print('ChatViewModel: Failed to send message: ${response['message']}');
      return {'success': false, 'message': response['message']};
    }
  }

  Future<Map<String, dynamic>> updateApplicationStatus(String status) async {
    print('ChatViewModel: updateApplicationStatus called with status: $status');
    print('  Current _applicationId: $_applicationId');
    print('  Current _currentUser ID: ${_currentUser?.id}');
    print('  Current _currentUser Role: ${_currentUser?.role}');


    if (_applicationId == null || _currentUser == null || _currentUser!.id == null) {
      print('ChatViewModel ERROR: Application ID or current user not identified. _applicationId: $_applicationId, _currentUser: ${_currentUser?.id}');
      return {"success": false, "message": "Application ID or current user not identified."};
    }

    _isLoadingMessages = true;
    notifyListeners();

    final int initiatorId = _currentUser!.id;

    final response = await _listingService.updateApplicationStatus(
      applicationId: _applicationId!,
      status: status,
      initiatorId: initiatorId,
    );

    _isLoadingMessages = false;
    if (response['success']) {
      _applicationStatus = status;
      print('ChatViewModel: Application status updated successfully to $_applicationStatus.');
      notifyListeners();
      await fetchMessages(); // Re-fetch messages to update UI with new system message
    } else {
      print('ChatViewModel: Failed to update application status: ${response['message']}');
      notifyListeners();
    }
    return response;
  }

  Future<Map<String, dynamic>> blockUser() async {
    print('ChatViewModel: blockUser called.');
    if (_currentUser == null || _recipientId == null) {
      print('ChatViewModel ERROR: Current user or recipient not identified for blocking.');
      return {"success": false, "message": "Current user or recipient not identified."};
    }

    final response = await _authService.blockUser(
      userId: _currentUser!.id,
      blockedUserId: _recipientId!,
    );
    print('ChatViewModel: Block user response: $response');
    return response;
  }
}