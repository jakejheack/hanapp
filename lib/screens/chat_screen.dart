import 'package:flutter/material.dart';
import 'package:hanapp/models/message.dart';
import 'package:hanapp/models/conversation.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/screens/view_profile_screen.dart';
import 'package:hanapp/services/chat_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'dart:async';
//import 'package:hanapp/utils/application_service.dart'; // For updating application status
import 'package:geolocator/geolocator.dart'; // Import geolocator for location services
import 'package:url_launcher/url_launcher.dart'; // For opening maps
import 'package:hanapp/screens/review_screen.dart';
import 'components/custom_button.dart'; // NEW: Import ActionService
import 'package:hanapp/services/notification_popup_service.dart';
import 'package:hanapp/models/notification_model.dart';
import 'package:hanapp/services/listing_service.dart';
import 'package:hanapp/screens/review_screen.dart';
import 'package:hanapp/services/action_service.dart';
import 'package:hanapp/services/application_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hanapp/utils/api_config.dart';
import 'package:hanapp/utils/word_filter_service.dart';
import 'package:hanapp/widgets/banned_words_dialog.dart';
import 'package:hanapp/screens/because_screen.dart';


// Dummy ViewProfileScreen for the IconButton in AppBar actions.
// Replace with your actual ViewProfileScreen if it exists.

class ChatScreen extends StatefulWidget {
  final int conversationId;
  final int otherUserId; // The ID of the person the current user is chatting with
  final String listingTitle;
  final int applicationId; // Can be null if chat is not linked to an application
  final bool isLister; // True if the current logged-in user is the lister of the associated listing
  // NEW: Add listerId and doerId of the conversation for notification context


  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.listingTitle,
    required this.applicationId,
    required this.isLister,

  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ApplicationService _applicationService = ApplicationService();
  final ScrollController _scrollController = ScrollController();
  final ActionService _actionService = ActionService(); // NEW: Instantiate ActionService

  // Animation controller for "Mark as Done" button wiggle
  late AnimationController _wiggleAnimationController;
  late Animation<double> _wiggleAnimation;

  List<Message> _messages = [];
  User? _currentUser;
  Conversation? _conversationDetails; // Stores detailed conversation info
  bool _isLoading = true; // Overall loading state for the screen
  String? _errorMessage;
  Timer? _messageFetchTimer; // Timer for periodic message fetching
  int _lastMessageId = 0; // To fetch new messages incrementally
  bool _isBlockedByCurrentUser = false; // NEW: Track if other user is blocked by current user
  User? _otherUser;
  bool _isConfirmingCompletion = false; // Separate loading state for confirm button
  bool _hasReview = true; // default to true to hide button until checked
  double? _listingPrice; // Add this variable for storing listing price

  @override
  void initState() {
    super.initState();
    
    // Initialize wiggle animation
    _wiggleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _wiggleAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _wiggleAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _initializeChat();
    _checkIfHasReview();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _wiggleAnimationController.dispose(); // Dispose animation controller
    _messageFetchTimer?.cancel(); // Cancel the timer to prevent memory leaks
    super.dispose();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _currentUser = await AuthService.getUser();
      if (_currentUser == null) {
        throw Exception("Current user not logged in or user ID is null.");
      }
      await _checkBlockedStatus();
      await _fetchConversationDetails();
      if (_conversationDetails != null) {
        await _fetchMessages();
        _startMessagePolling();
        
        // Start wiggle animation for "Mark as Done" button if user is doer and job is in progress
        if (!widget.isLister && _conversationDetails!.applicationStatus == 'in_progress') {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              _startWiggleAnimation();
            }
          });
        }
      } else {
        throw Exception(_errorMessage ?? "Failed to load conversation details, cannot fetch messages.");
      }
    } catch (e) {
      debugPrint('ChatScreen _initializeChat error: $e');
      setState(() {
        _errorMessage = "Failed to load chat: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIfHasReview() async {
    final applicationId = widget.applicationId;
    print('DEBUG: ENTERED _checkIfHasReview for applicationId: $applicationId');
    if (applicationId != null) {
      print('DEBUG: Checking if review exists for application $applicationId');
      final url = Uri.parse('${ApiConfig.baseUrl}/reviews/has_review.php?application_id=$applicationId');
      print('DEBUG: Requesting URL: $url');
      // Set a User-Agent header to mimic a browser
      final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
      print('DEBUG: hasReview raw response: \\${response.body}');
      try {
        final data = jsonDecode(response.body);
        print('DEBUG: Decoded data: $data');
        print('DEBUG: has_review type: \\${data['has_review']?.runtimeType}');
        final hasReview = data['has_review'] == true || data['has_review'] == 'true';
        print('DEBUG: Parsed hasReview: \\${data['has_review']} -> $hasReview');
        setState(() {
          _hasReview = hasReview;
        });
      } catch (e) {
        print('DEBUG: Error parsing hasReview response: $e');
        setState(() {
          _hasReview = false;
        });
      }
    } else {
      print('DEBUG: No applicationId provided, cannot check for review');
    }
  }

  // NEW: Method to check blocked status
  Future<void> _checkBlockedStatus() async {
    if (_currentUser == null) return;
    final response = await _actionService.getBlockedStatus(
      currentUserId: _currentUser!.id!,
      targetUserId: widget.otherUserId,
    );
    if (response['success']) {
      setState(() {
        _isBlockedByCurrentUser = response['is_blocked'];
      });
    } else {
      _showSnackBar(response['message'] ?? 'Failed to check block status.', isError: true);
    }
  }

  void _startMessagePolling() {
    _messageFetchTimer?.cancel();
    _messageFetchTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchMessages(isPolling: true);
    });
  }

  Future<void> _fetchConversationDetails() async {
    if (widget.conversationId == null) {
      setState(() {
        _errorMessage = 'Conversation ID is missing';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await _chatService.getConversationDetails(widget.conversationId!);
      
      if (response['success'] == true && response['details'] != null) {
        setState(() {
          _conversationDetails = Conversation.fromJson(response['details']);
          _errorMessage = null;
        });
        
        // Fetch listing price
        await _fetchListingPrice();
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load conversation details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading conversation details: $e';
        _isLoading = false;
      });
      debugPrint('Error fetching conversation details: $e');
    }
  }

  Future<void> _fetchListingPrice() async {
    if (_conversationDetails == null) return;
    
    try {
      final listingService = ListingService();
      final listingResponse = await listingService.getListingDetails(listingId: _conversationDetails!.listingId);
      
      if (listingResponse['success'] == true && listingResponse['listing'] != null) {
        final listing = listingResponse['listing'];
        final price = (listing['price'] as num?)?.toDouble();
        
        setState(() {
          _listingPrice = price ?? 500.0; // Default fallback
        });
      }
    } catch (e) {
      debugPrint('Error fetching listing price: $e');
      setState(() {
        _listingPrice = 500.0; // Default fallback
      });
    }
  }

  Future<void> _fetchMessages({bool isPolling = false}) async {
    if (_currentUser == null || _currentUser!.id == null || _conversationDetails == null) {
      debugPrint('ChatScreen: Cannot fetch messages. Current user or conversation details missing.');
      return;
    }

    debugPrint('ChatScreen: Fetching messages for conversation ${widget.conversationId} from lastMessageId: $_lastMessageId (isPolling: $isPolling)');
    final response = await _chatService.getMessages(
      conversationId: widget.conversationId,
      lastMessageId: _lastMessageId,
    );

    if (response['success'] && response['messages'] != null) {
      List<Message> newMessages = (response['messages'] as List)
          .map((msgJson) => Message.fromJson(msgJson as Map<String, dynamic>))
          .toList();

      if (newMessages.isNotEmpty) {
        setState(() {
          final existingIds = _messages.map((m) => m.id).toSet();
          final uniqueNewMessages = newMessages.where((m) => !existingIds.contains(m.id)).toList();
          _messages.addAll(uniqueNewMessages);
          _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
          if (_messages.isNotEmpty) {
            _lastMessageId = _messages.last.id;
          }
        });
        if (!isPolling || (_scrollController.hasClients && _scrollController.position.pixels == _scrollController.position.maxScrollExtent)) {
          _scrollToBottom();
        }
        debugPrint('ChatScreen: Fetched ${newMessages.length} new messages. Total: ${_messages.length}');
      } else {
        debugPrint('ChatScreen: No new messages fetched.');
      }
    } else {
      if (!isPolling) {
        _showSnackBar(response['message'] ?? 'Failed to fetch messages.', isError: true);
      }
      debugPrint('ChatScreen: Failed to fetch messages during polling: ${response['message']}');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Method to start wiggle animation for "Mark as Done" button
  void _startWiggleAnimation() {
    _wiggleAnimationController.repeat(reverse: true);
  }

  // Method to stop wiggle animation
  void _stopWiggleAnimation() {
    _wiggleAnimationController.stop();
  }

  Future<void> _sendMessage({String messageType = 'text', String messageContent = '', Map<String, dynamic>? extraData}) async {
    if (messageType == 'text' && _messageController.text.trim().isEmpty) return;

    if (_currentUser == null || _isBlockedByCurrentUser) {
      if (_isBlockedByCurrentUser) {
        _showSnackBar('You have blocked this user. Unblock them to send messages.', isError: true);
      }
      return;
    }

    final messageContentToSend = messageType == 'text' ? _messageController.text.trim() : messageContent;
    
    // Check for banned words in the message content
    if (messageType == 'text' && messageContentToSend.isNotEmpty) {
      print('ChatScreen: Checking message for banned words: "$messageContentToSend"');
      final bannedWords = await WordFilterService().findBannedWords(messageContentToSend);
      
      if (bannedWords.isNotEmpty) {
        print('ChatScreen: Banned words detected in message');
        // Show banned words dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return BannedWordsDialog(
              bannedWordsByField: {'message': bannedWords['text'] ?? []},
            );
          },
        );
        return; // Don't send the message
      }
    }
    
    _messageController.clear();

    await _chatService.sendMessage(
      conversationId: widget.conversationId,
      senderId: _currentUser!.id!,
      receiverId: widget.otherUserId,
      messageContent: messageContentToSend,
      messageType: messageType,
      // extraData: extraData,
      // listingId: widget.applicationId,
    );
  }
  // Future<void> _sendMessage() async {
  //   if (_messageController.text.trim().isEmpty || _currentUser == null || _currentUser!.id == null || _conversationDetails == null || _isBlockedByCurrentUser) {
  //     return;
  //   }
  //
  //   final String messageContent = _messageController.text.trim();
  //   _messageController.clear();
  //
  //   final optimisticMessage = Message(
  //     id: -(_messages.length + 1),
  //     conversationId: widget.conversationId,
  //     senderId: _currentUser!.id!,
  //     receiverId: widget.otherUserId,
  //     content: messageContent,
  //     sentAt: DateTime.now(),
  //     type: 'text',
  //   );
  //
  //   setState(() {
  //     _messages.add(optimisticMessage);
  //     _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
  //   });
  //   _scrollToBottom();
  //
  //   final response = await _chatService.sendMessage(
  //     conversationId: widget.conversationId,
  //     senderId: _currentUser!.id!,
  //     receiverId: widget.otherUserId,
  //     messageContent: messageContent,
  //     messageType: 'text',
  //   );
  //
  //   if (!response['success']) {
  //     _showSnackBar('Failed to send message: ${response['message']}', isError: true);
  //     _fetchMessages();
  //   } else {
  //     _fetchMessages();
  //   }
  // }

  Future<void> _handleStartProject() async {
    if (_currentUser == null || _currentUser!.id == null || _conversationDetails == null) {
      _showSnackBar('Error: Missing user or conversation data to start project.', isError: true);
      return;
    }
    if (!widget.isLister) {
      _showSnackBar('Only the Lister can start the project.', isError: true);
      return;
    }
    
    // For ASAP listings without application, we'll create one
    if (_conversationDetails!.listingType == 'ASAP' && widget.applicationId == null) {
      await _handleStartAsapProject();
      return;
    }
    
    // For regular listings with applications
    if (widget.applicationId == null) {
      _showSnackBar('Error: Application data missing to start project.', isError: true);
      return;
    }
    
    if (_conversationDetails!.applicationStatus != 'pending' && _conversationDetails!.applicationStatus != 'accepted') {
      _showSnackBar('Project can only be started if application status is "pending" or "accepted". Current status: ${_conversationDetails!.applicationStatus}.', isError: true);
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Start Project'),
          content: const Text('Are you sure you want to mark this project as "In Progress"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() { _isLoading = true; });
      try {
        final response = await _applicationService.updateApplicationStatus(
          applicationId: widget.applicationId!,
          newStatus: 'in_progress',
          currentUserId: _currentUser!.id!,
        );

        if (response['success']) {
          _showSnackBar(response['message'] ?? 'Project marked as In Progress.');
          
          // Create and show popup notification for the doer
          if (_otherUser != null) {
            final notification = NotificationModel(
              id: 0, // This will be set by the backend
              userId: widget.otherUserId, // Doer's ID
              senderId: _currentUser!.id, // Lister's ID
              type: 'project_started',
              title: 'Project Started',
              content: "The project '${widget.listingTitle}' has started. Good luck with your work!",
              createdAt: DateTime.now(),
              isRead: false,
              associatedId: widget.applicationId,
              relatedListingTitle: widget.listingTitle,
            );
            
            // Show popup notification for the doer
            NotificationPopupService().showNotification(context, notification);
          }
          
          await _fetchConversationDetails();

          // Send a system message to inform both parties
          await _chatService.sendMessage(
            conversationId: widget.conversationId,
            senderId: _currentUser!.id!,
            receiverId: widget.otherUserId,
            messageContent: "${_currentUser!.fullName} started the project. A project start date has been recorded.",
            messageType: 'system',
          );
          await _fetchMessages();

        } else {
          _showSnackBar('Failed to start project: ${response['message']}', isError: true);
        }
      } catch (e) {
        _showSnackBar('Error starting project: $e', isError: true);
        debugPrint('Error starting project: $e');
      } finally {
        setState(() { _isLoading = false; });
      }
    }
  }

  // NEW: Handle starting ASAP projects by creating an application first
  Future<void> _handleStartAsapProject() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Start ASAP Project'),
          content: const Text('Are you sure you want to start this ASAP project? This will create an application and mark the project as "In Progress".'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() { _isLoading = true; });
      try {
        // Create an application for the ASAP listing
        final createResponse = await _applicationService.createApplication(
          listingId: _conversationDetails!.listingId,
          listingType: 'ASAP',
          listerId: _conversationDetails!.listerId,
          doerId: _conversationDetails!.doerId,
          message: 'ASAP project started by lister',
          listingTitle: _conversationDetails!.listingTitle ?? 'ASAP Project',
        );

        if (createResponse['success']) {
          // Get the application ID from the response
          final int? newApplicationId = createResponse['application_id'];
          
          if (newApplicationId != null) {
            // Update the application status to in_progress
            final updateResponse = await _applicationService.updateApplicationStatus(
              applicationId: newApplicationId,
              newStatus: 'in_progress',
              currentUserId: _currentUser!.id!,
            );

            if (updateResponse['success']) {
              _showSnackBar('ASAP project started successfully!');
              
              // Create and show popup notification for the doer
              if (_otherUser != null) {
                final notification = NotificationModel(
                  id: 0, // This will be set by the backend
                  userId: widget.otherUserId, // Doer's ID
                  senderId: _currentUser!.id, // Lister's ID
                  type: 'project_started',
                  title: 'ASAP Project Started',
                  content: "The ASAP project '${_conversationDetails!.listingTitle ?? 'ASAP Project'}' has started. Good luck with your work!",
                  createdAt: DateTime.now(),
                  isRead: false,
                  associatedId: newApplicationId,
                  relatedListingTitle: _conversationDetails!.listingTitle ?? 'ASAP Project',
                );
                
                // Show popup notification for the doer
                NotificationPopupService().showNotification(context, notification);
              }
              
              await _fetchConversationDetails();

              // Send a system message to inform both parties
              await _chatService.sendMessage(
                conversationId: widget.conversationId,
                senderId: _currentUser!.id!,
                receiverId: widget.otherUserId,
                messageContent: "${_currentUser!.fullName} started the ASAP project. A project start date has been recorded.",
                messageType: 'system',
              );
              await _fetchMessages();
            } else {
              _showSnackBar('Failed to update project status: ${updateResponse['message']}', isError: true);
            }
          } else {
            _showSnackBar('Failed to get application ID after creation.', isError: true);
          }
        } else {
          _showSnackBar('Failed to create application: ${createResponse['message']}', isError: true);
        }
      } catch (e) {
        _showSnackBar('Error starting ASAP project: $e', isError: true);
        debugPrint('Error starting ASAP project: $e');
      } finally {
        setState(() { _isLoading = false; });
      }
    }
  }

// NEW: Method to handle reporting a user
  Future<void> _reportUser() async {
    if (_currentUser == null) return;

    final TextEditingController reasonController = TextEditingController();
    final TextEditingController detailsController = TextEditingController();
    String? selectedReason;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Report User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: <String>[
                    'Inappropriate Content',
                    'Spam or Scam',
                    'Harassment',
                    'Fraudulent Activity',
                    'Other'
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    selectedReason = newValue;
                  },
                  validator: (value) => value == null ? 'Please select a reason' : null,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Brief Reason',
                    hintText: 'e.g., Offensive language',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Details (Optional)',
                    hintText: 'Provide more context about the report.',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Submit Report'),
              onPressed: () async {
                if (selectedReason == null || reasonController.text.trim().isEmpty) {
                  _showSnackBar('Please select a reason and provide a brief reason.', isError: true);
                  return;
                }

                Navigator.of(context).pop(); // Close dialog first

                final response = await _actionService.reportUser(
                  reporterUserId: _currentUser!.id!,
                  reportedUserId: widget.otherUserId,
                  listingId: widget.applicationId, // Pass application ID as context
                  reportReason: selectedReason!, // Use the selected reason
                  reportDetails: detailsController.text.trim().isEmpty ? null : detailsController.text.trim(),
                );

                if (response['success']) {
                  _showSnackBar(response['message'] ?? 'Report submitted successfully!');
                } else {
                  _showSnackBar('Failed to submit report: ${response['message']}', isError: true);
                }
              },
            ),
          ],
        );
      },
    );
    reasonController.dispose();
    detailsController.dispose();
  }
// NEW: Method to handle blocking/unblocking a user
  Future<void> _toggleBlockUser() async {
    if (_currentUser == null) return;

    String actionMessage = _isBlockedByCurrentUser ? 'unblock' : 'block';
    String confirmMessage = _isBlockedByCurrentUser
        ? 'Are you sure you want to unblock ${_otherUser?.fullName ?? 'this user'}? You will be able to send and receive messages again.'
        : 'Are you sure you want to block ${_otherUser?.fullName ?? 'this user'}? You will no longer be able to send or receive messages from them.';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirm $actionMessage'),
          content: Text(confirmMessage),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            CustomButton( // Using CustomButton
              text: actionMessage == 'block' ? 'Block' : 'Unblock',
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              color: actionMessage == 'block' ? Colors.red : Constants.primaryColor,
              textColor: Colors.white,
              borderRadius: 8.0,
              height: 40.0,
              width: actionMessage == 'block' ? 80 : 100,
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      Map<String, dynamic> response;
      if (_isBlockedByCurrentUser) {
        response = await _actionService.unblockUser(
          userId: _currentUser!.id!,
          blockedUserId: widget.otherUserId,
        );
      } else {
        response = await _actionService.blockUser(
          userId: _currentUser!.id!,
          blockedUserId: widget.otherUserId,
        );
      }

      if (response['success']) {
        _showSnackBar(response['message'] ?? 'Action successful!');
        await _checkBlockedStatus(); // Re-check status to update UI
      } else {
        _showSnackBar('Failed to $actionMessage user: ${response['message']}', isError: true);
      }
    }
  }
  Future<void> _handleRejectApplication() async {
    if (_currentUser == null || _currentUser!.id == null || _conversationDetails == null || widget.applicationId == null) {
      _showSnackBar('Error: Missing user or conversation data to reject application.', isError: true);
      return;
    }
    if (!widget.isLister) {
      _showSnackBar('Only the Lister can reject an application.', isError: true);
      return;
    }
    if (_conversationDetails!.applicationStatus == 'rejected' || _conversationDetails!.applicationStatus == 'completed') {
      _showSnackBar('Application is already rejected or completed.', isError: true);
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Reject Application'),
          content: const Text('Are you sure you want to reject this application? This cannot be easily undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() { _isLoading = true; });
      try {
        final response = await _applicationService.updateApplicationStatus(
          applicationId: widget.applicationId!,
          newStatus: 'rejected',
          currentUserId: _currentUser!.id!,
        );

        if (response['success']) {
          _showSnackBar(response['message'] ?? 'Application rejected.');
          
          // Create and show popup notification for the doer
          if (_otherUser != null) {
            final notification = NotificationModel(
              id: 0, // This will be set by the backend
              userId: widget.otherUserId, // Doer's ID
              senderId: _currentUser!.id, // Lister's ID
              type: 'application_rejected',
              title: 'Application Rejected',
              content: "Your application for '${widget.listingTitle}' has been rejected by the lister.",
              createdAt: DateTime.now(),
              isRead: false,
              associatedId: widget.applicationId,
              relatedListingTitle: widget.listingTitle,
            );
            
            // Show popup notification for the doer
            NotificationPopupService().showNotification(context, notification);
          }
          
          await _fetchConversationDetails();
          await _chatService.sendMessage(
            conversationId: widget.conversationId,
            senderId: _currentUser!.id!,
            receiverId: widget.otherUserId,
            messageContent: "Your application has been marked as 'Rejected' by the Lister.",
            messageType: 'system',
          );
          _fetchMessages();
        } else {
          _showSnackBar('Failed to reject application: ${response['message']}', isError: true);
        }
      } catch (e) {
        _showSnackBar('Error rejecting application: $e', isError: true);
        debugPrint('Error rejecting application: $e');
      } finally {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled. Please enable them.', isError: true);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied. Cannot share location.', isError: true);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions are permanently denied. Please enable them from app settings.', isError: true);
      return;
    }
    return;
  }

  Future<void> _shareCurrentLocation() async {
    if (_currentUser == null || _currentUser!.id == null || _conversationDetails == null) {
      _showSnackBar('Error: User or conversation data missing.', isError: true);
      return;
    }

    setState(() { _isLoading = true; });
    try {
      await _checkLocationPermissions();

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final String locationMessage = "My current location: latitude ${position.latitude}, longitude ${position.longitude}";
      final String mapLink = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";

      final response = await _chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: _currentUser!.id!,
        receiverId: widget.otherUserId,
        messageContent: locationMessage,
        messageType: 'location_share',
        locationData: {'latitude': position.latitude, 'longitude': position.longitude, 'mapLink': mapLink},
      );

      if (response['success']) {
        _showSnackBar('Location shared successfully!');
        _fetchMessages();
      } else {
        _showSnackBar('Failed to share location: ${response['message']}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error getting/sharing location: $e', isError: true);
      debugPrint('Error getting/sharing location: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _viewCurrentLocation(String locationString) async {
    final latLngRegex = RegExp(r'latitude\s*(-?\d+\.?\d*),\s*longitude\s*(-?\d+\.?\d*)');
    final match = latLngRegex.firstMatch(locationString);

    if (match != null) {
      final latitude = double.parse(match.group(1)!);
      final longitude = double.parse(match.group(2)!);
      final url = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        _showSnackBar('Could not open map for $locationString', isError: true);
      }
    } else {
      _showSnackBar('Could not parse location string: $locationString', isError: true);
    }
  }

  Future<void> _handleMarkAsDone() async {
    if (_currentUser == null || _currentUser!.id == null || _conversationDetails == null || widget.applicationId == null) {
      _showSnackBar('Error: Missing user or conversation data to mark as done.', isError: true);
      return;
    }
    if (widget.isLister) {
      _showSnackBar('Only the Doer can mark a project as done.', isError: true);
      return;
    }
    if (_conversationDetails!.applicationStatus != 'in_progress') {
      _showSnackBar('Project must be "In Progress" to be marked as done. Current status: ${_conversationDetails!.applicationStatus}.', isError: true);
      return;
    }

    // Stop the wiggle animation when user clicks the button
    _stopWiggleAnimation();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Mark as Done'),
          content: const Text('Are you sure you want to mark this project as "Done"? The Lister will need to confirm completion.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Mark Done'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() { _isLoading = true; });
      try {
        // Send a system message to notify the Lister that the Doer marked it as done
        final response = await _chatService.sendMessage(
          conversationId: widget.conversationId,
          senderId: _currentUser!.id!,
          receiverId: widget.otherUserId,
          messageContent: "${_currentUser!.fullName} marked the project as done. Please confirm.",
          messageType: 'doer_marked_complete_request', // New message type
        );

        if (response['success']) {
          _showSnackBar(response['message'] ?? 'Project marked as done. Waiting for Lister confirmation.');
          await _fetchMessages(); // Refresh messages to show the new system message
          // The application status remains 'in_progress' until the Lister confirms.
        } else {
          _showSnackBar('Failed to mark as done: ${response['message']}', isError: true);
        }
      } catch (e) {
        _showSnackBar('Error marking as done: $e', isError: true);
        debugPrint('Error marking as done: $e');
      } finally {
        setState(() { _isLoading = false; });
      }
    }
  }
// FIXED: Handle Lister's confirmation of project completion
  Future<void> _handleConfirmCompletion() async {
    // Check for necessary data more robustly
    if (_currentUser == null || _currentUser!.id == null || _currentUser!.id == 0 ||
        widget.applicationId == 0 || // Assuming 0 is an invalid default for applicationId
        widget.otherUserId == 0 || // Assuming 0 is an invalid default for otherUserId
        widget.listingTitle.isEmpty) {
      _showSnackBar('Error: Missing user or application data to confirm completion.', isError: true);
      // Log the specific missing values for debugging
      debugPrint('CONFIRM COMPLETION ERROR: _currentUser: ${_currentUser?.id}, '
          'applicationId: ${widget.applicationId}, '
          'otherUserId: ${widget.otherUserId}, '
          'listingTitle: "${widget.listingTitle}"');
      return;
    }

    if (!widget.isLister) {
      _showSnackBar('Only the Lister can confirm project completion.', isError: true);
      return;
    }

    if (_isConfirmingCompletion) return; // Prevent multiple taps

    setState(() {
      _isConfirmingCompletion = true;
    });

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Completion'),
          content: Text('Are you sure you want to mark "${widget.listingTitle}" as complete with ${_otherUser?.fullName ?? 'this doer'}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            CustomButton(
              text: 'Confirm',
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              color: Constants.primaryColor,
              textColor: Colors.white,
              borderRadius: 8.0,
              height: 40.0,
              width: 80,
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final response = await _applicationService.updateApplicationStatus(
          applicationId: widget.applicationId, // Now guaranteed to be non-null/non-zero
          newStatus: 'completed',
          currentUserId: _currentUser!.id!, // Current user is the Lister
        );

        if (response['success']) {
          _showSnackBar(response['message'] ?? 'Project confirmed as completed.');

          // Create and show popup notification for the doer
          if (_otherUser != null) {
            final notification = NotificationModel(
              id: 0, // This will be set by the backend
              userId: widget.otherUserId, // Doer's ID
              senderId: _currentUser!.id, // Lister's ID
              type: 'job_completed_by_lister',
              title: 'Job Completed by Lister',
              content: "Congratulations! The lister has marked the job '${widget.listingTitle}' as completed.",
              createdAt: DateTime.now(),
              isRead: false,
              associatedId: widget.applicationId,
              listingId: _conversationDetails?.listingId,
              senderFullName: _currentUser!.fullName,
              conversationIdForChat: widget.conversationId,
              listerIdForChat: _currentUser!.id,
              doerIdForChat: widget.otherUserId,
              relatedListingTitle: widget.listingTitle,
            );
            
            // Show popup notification for the doer
            NotificationPopupService().showNotification(context, notification);
          }

          // Send a system message to indicate project completion
          await _sendMessage(
            messageType: 'system',
            messageContent: "${_currentUser!.fullName} has confirmed the project completion. You can now leave a review.",
            extraData: {
              'action': 'doer_marked_completed_request', // Example action for a specific UI/backend trigger
            },
          );

          // After successful completion and sending system message, navigate to review screen
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ReviewScreen(
                reviewerId: _currentUser!.id!,
                reviewedUserId: widget.otherUserId,
                listingId: widget.applicationId,
                listingTitle: widget.listingTitle,
              ),
            ),
          ).then((_) => _checkIfHasReview());

        } else {
          _showSnackBar('Failed to confirm completion: ${response['message']}', isError: true);
        }
      } catch (e) {
        _showSnackBar('Error confirming completion: ${e.toString()}', isError: true);
        debugPrint('Error confirming completion: $e');
      }
    }

    setState(() {
      _isConfirmingCompletion = false; // Reset loading state
    });
  }

  Future<void> _handleAcceptApplication() async {
    if (_currentUser == null || _currentUser!.id == null || _conversationDetails == null || widget.applicationId == null) {
      _showSnackBar('Error: Missing user or conversation data to accept application.', isError: true);
      return;
    }
    if (!widget.isLister) {
      _showSnackBar('Only the Lister can accept an application.', isError: true);
      return;
    }
    if (_conversationDetails!.applicationStatus == 'accepted' || _conversationDetails!.applicationStatus == 'completed') {
      _showSnackBar('Application is already accepted or completed.', isError: true);
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Accept Application'),
          content: const Text('Are you sure you want to accept this application?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() { _isLoading = true; });
      try {
        final response = await _applicationService.updateApplicationStatus(
          applicationId: widget.applicationId!,
          newStatus: 'accepted',
          currentUserId: _currentUser!.id!,
        );

        if (response['success']) {
          _showSnackBar(response['message'] ?? 'Application accepted.');
          
          // Create and show popup notification for the doer
          if (_otherUser != null) {
            final notification = NotificationModel(
              id: 0, // This will be set by the backend
              userId: widget.otherUserId, // Doer's ID
              senderId: _currentUser!.id, // Lister's ID
              type: 'application_accepted',
              title: 'Application Accepted',
              content: "Congratulations! Your application for '${widget.listingTitle}' has been accepted by the lister.",
              createdAt: DateTime.now(),
              isRead: false,
              associatedId: widget.applicationId,
              relatedListingTitle: widget.listingTitle,
            );
            
            // Show popup notification for the doer
            NotificationPopupService().showNotification(context, notification);
          }
          
          await _fetchConversationDetails();
          await _chatService.sendMessage(
            conversationId: widget.conversationId,
            senderId: _currentUser!.id!,
            receiverId: widget.otherUserId,
            messageContent: "Your application has been marked as 'Accepted' by the Lister.",
            messageType: 'system',
          );
          _fetchMessages();
        } else {
          _showSnackBar('Failed to accept application: ${response['message']}', isError: true);
        }
      } catch (e) {
        _showSnackBar('Error accepting application: $e', isError: true);
        debugPrint('Error accepting application: $e');
      } finally {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  // Add new method to handle payment for completed job
  Future<void> _handlePaymentForCompletedJob() async {
    if (_conversationDetails == null || widget.applicationId == null) {
      _showSnackBar('Error: Missing conversation or application data.', isError: true);
      return;
    }

    // Use the stored listing price or default
    final jobAmount = _listingPrice ?? 500.0;
    
    if (jobAmount <= 0) {
      _showSnackBar('Error: Invalid job amount for payment.', isError: true);
      return;
    }

    // Navigate to payment screen with pre-filled amount
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BecauseScreen(
          preFilledAmount: jobAmount,
          isJobPayment: true,
          applicationId: widget.applicationId!.toString(), // Convert int to String
          listingTitle: widget.listingTitle,
        ),
      ),
    );

    // Check if payment was successful
    if (result == true) {
      // Payment successful - update job status to completed and show review button
      await _updateJobStatusAfterPayment();
    }
  }

  // Update job status after successful payment
  Future<void> _updateJobStatusAfterPayment() async {
    if (_currentUser == null || _currentUser!.id == null || widget.applicationId == null) {
      _showSnackBar('Error: Missing user or application data.', isError: true);
      return;
    }

    setState(() { _isLoading = true; });
    
    try {
      // Update application status to completed
      final response = await _applicationService.updateApplicationStatus(
        applicationId: widget.applicationId!,
        newStatus: 'completed',
        currentUserId: _currentUser!.id!,
      );

      if (response['success']) {
        _showSnackBar('Payment successful! Job marked as completed.');
        
        // Send system message about payment completion
        await _chatService.sendMessage(
          conversationId: widget.conversationId,
          senderId: _currentUser!.id!,
          receiverId: widget.otherUserId,
          messageContent: "Payment completed successfully. Job marked as completed.",
          messageType: 'payment_completed',
        );
        
        // Refresh conversation details to show review button
        await _fetchConversationDetails();
        await _fetchMessages();
        
        // Show success message and prompt for review
        _showPaymentSuccessDialog();
      } else {
        _showSnackBar('Failed to update job status: ${response['message']}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error updating job status: $e', isError: true);
      debugPrint('Error updating job status after payment: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // Show payment success dialog
  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text('Payment Successful!'),
            ],
          ),
          content: const Text(
            'Your payment has been processed successfully. The job is now marked as completed.\n\n'
            'Would you like to leave a review for the doer?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to review screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ReviewScreen(
                      reviewerId: _currentUser!.id!,
                      reviewedUserId: _conversationDetails!.doerId,
                      listingId: widget.applicationId,
                      listingTitle: _conversationDetails!.listingTitle,
                    ),
                  ),
                ).then((_) => _checkIfHasReview());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Leave Review'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Constants.primaryColor,
          foregroundColor: Colors.white,
          title: const Text('Loading Chat...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Constants.primaryColor,
          foregroundColor: Colors.white,
          title: const Text('Chat Error'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      );
    }

    final String otherUserName = _conversationDetails?.getOtherUserFullName(_currentUser?.id ?? 0) ?? 'Unknown User';
    final String? otherUserLocation = _conversationDetails?.getOtherUserAddress(_currentUser?.id ?? 0);
    final String? otherUserProfilePic = _conversationDetails?.getOtherUserProfilePictureUrl(_currentUser?.id ?? 0);
    final String? currentUserProfilePic = _currentUser?.profilePictureUrl;


    String? currentApplicationStatus = _conversationDetails?.applicationStatus;
    String statusDisplay = currentApplicationStatus?.toUpperCase().replaceAll('_', ' ') ?? 'N/A';
    Color statusColor = Colors.grey;

    if (currentApplicationStatus == 'pending') {
      statusColor = Colors.orange;
    } else if (currentApplicationStatus == 'accepted') {
      statusColor = Colors.blue;
    } else if (currentApplicationStatus == 'in_progress') {
      statusDisplay = 'ONGOING';
      statusColor = Colors.green;
    } else if (currentApplicationStatus == 'completed') {
      statusColor = Colors.teal;
    } else if (currentApplicationStatus == 'rejected' || currentApplicationStatus == 'cancelled') {
      statusColor = Colors.red;
    }

    print('Current application status: [32m${_conversationDetails?.applicationStatus}[0m');
    print('hasReview: [32m$_hasReview[0m, currentUser: [32m${_currentUser?.id}[0m, listerId: [32m${_conversationDetails?.listerId}[0m');
    print('DEBUG: applicationId: ${widget.applicationId}');

    // Debug prints for Leave a Review button logic
    print('DEBUG: Checking Leave a Review button conditions:');
    print('  - _hasReview: $_hasReview');
    print('  - _currentUser?.id: ${_currentUser?.id}');
    print('  - _conversationDetails?.listerId: ${_conversationDetails?.listerId}');
    print('  - currentApplicationStatus: $currentApplicationStatus');
    print('  - Should show button: ${!_hasReview && _currentUser?.id == _conversationDetails?.listerId}');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    otherUserName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                // Display status in app bar
                if (currentApplicationStatus != null && currentApplicationStatus.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusDisplay,
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            if (otherUserLocation != null && otherUserLocation.isNotEmpty)
              Text(
                otherUserLocation,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: _isLoading ? null : () async {
              setState(() { _isLoading = true; });
              try {
                await _fetchConversationDetails();
                await _fetchMessages();
              } catch (e) {
                _showSnackBar('Failed to refresh: $e', isError: true);
              } finally {
                setState(() { _isLoading = false; });
              }
            },
            tooltip: 'Refresh Chat',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') {
                _reportUser();
              } else if (value == 'block') {
                _toggleBlockUser();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'report',
                child: Text('Report User'),
              ),
              PopupMenuItem<String>(
                value: 'block',
                child: Text(_isBlockedByCurrentUser ? 'Unblock User' : 'Block User'), // Dynamic text
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.listingTitle,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Constants.textColor),
                ),
                const SizedBox(height: 10),
                // Conditional buttons for Lister and Doer
                // Lister's initial buttons (Reject/Start) - visible for pending/accepted or ASAP listings
                if (widget.isLister &&
                    ((widget.applicationId != null && (currentApplicationStatus == 'pending' || currentApplicationStatus == 'accepted')) ||
                     (_conversationDetails?.listingType == 'ASAP' && widget.applicationId == null)) &&
                    !(currentApplicationStatus == 'completed' && _hasReview))
                  Row(
                    children: [
                      // Only show Reject button if there's an application
                      if (widget.applicationId != null)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRejectApplication,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Reject', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      if (widget.applicationId != null)
                        const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleStartProject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Constants.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Start', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                // Lister's "View Current Location" button (when in_progress and not yet marked done by doer)
                // This button should *not* show if there's a pending 'doer_marked_complete_request'
                if (widget.applicationId != null && widget.isLister &&
                    currentApplicationStatus == 'in_progress' &&
                    !_messages.any((msg) => msg.type == 'doer_marked_complete_request' && msg.senderId == widget.otherUserId))
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () {
                        final lastLocationMessage = _messages.lastWhere(
                              (msg) => msg.type == 'location_share' && msg.senderId == widget.otherUserId,
                          orElse: () => Message(id: -1, conversationId: -1, senderId: -1, receiverId: -1, content: '', sentAt: DateTime.now(), type: 'none'),
                        );
                        if (lastLocationMessage.id != -1 && lastLocationMessage.content.isNotEmpty) {
                          _viewCurrentLocation(lastLocationMessage.content);
                        } else {
                          _showSnackBar('No location shared by Doer yet.', isError: true);
                        }
                      },
                      icon: const Icon(Icons.location_on),
                      label: const Text('View Current Location', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      ),
                    ),
                  ),

                // Doer's "Share Location" and "Mark as Done" buttons (when in_progress)
                // This button should *not* show if the doer has already sent a 'doer_marked_complete_request'
                if (widget.applicationId != null && !widget.isLister &&
                    currentApplicationStatus == 'in_progress' &&
                    !_messages.any((msg) => msg.type == 'doer_marked_complete_request' && msg.senderId == _currentUser!.id))
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _shareCurrentLocation,
                          icon: const Icon(Icons.share_location),
                          label: const Text('Share Location', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Constants.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _wiggleAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_wiggleAnimation.value * 10.0, 0), // 10 pixels left-right wiggle
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _handleMarkAsDone,
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Mark as Done', style: TextStyle(fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                // Display final status text if no active buttons are shown
                if (currentApplicationStatus != null && (currentApplicationStatus == 'completed' || currentApplicationStatus == 'rejected' || currentApplicationStatus == 'cancelled'))
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(
                        'Project ${statusDisplay}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ),
                
                // Payment button for confirmed but unpaid jobs
                if (widget.isLister &&
                    _currentUser?.id == _conversationDetails?.listerId &&
                    currentApplicationStatus == 'in_progress' &&
                    _messages.any((msg) => msg.type == 'doer_marked_complete_request' && msg.senderId == widget.otherUserId) &&
                    !_messages.any((msg) => msg.type == 'payment_completed' && msg.senderId == _currentUser!.id)) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handlePaymentForCompletedJob,
                        icon: const Icon(Icons.payment, color: Colors.white),
                        label: Text(
                          'Pay ₱${_listingPrice?.toStringAsFixed(2) ?? '500.00'}', // Use the stored listing price or default
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
                // Review button for completed and paid jobs
                if (!_hasReview &&
                    _currentUser?.id == _conversationDetails?.listerId &&
                    currentApplicationStatus == 'completed' &&
                    widget.isLister &&
                    _messages.any((msg) => msg.type == 'payment_completed' && msg.senderId == _currentUser!.id)) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => ReviewScreen(
                              reviewerId: _currentUser!.id!,
                              reviewedUserId: _conversationDetails!.doerId,
                              listingId: widget.applicationId,
                              listingTitle: _conversationDetails!.listingTitle,
                            ),
                          )).then((_) => _checkIfHasReview());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        ),
                        child: const Text('Leave a Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                try {
                  await _fetchConversationDetails();
                  await _fetchMessages();
                } catch (e) {
                  _showSnackBar('Failed to refresh: $e', isError: true);
                }
              },
              color: Constants.primaryColor,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final bool isMe = message.senderId == _currentUser?.id;
                  final bool isSystemMessage = message.type == 'system';
                  final bool isLocationMessage = message.type == 'location_share';
                  final bool isDoerMarkedCompleteRequest = message.type == 'doer_marked_complete_request';

                  if (isSystemMessage) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            message.content,
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  } else if (isLocationMessage) {
                    return MessageBubble(
                      message: message,
                      isMe: isMe,
                      otherUserProfilePic: otherUserProfilePic,
                      currentUserProfilePic: currentUserProfilePic,
                      onLocationTap: (latLngString) {
                        _viewCurrentLocation(latLngString);
                      },
                    );
                  } else if (isDoerMarkedCompleteRequest) {
                    // NEW: Render special UI for Doer Marked Complete Request on Lister side
                    if (widget.isLister &&
                        currentApplicationStatus == 'in_progress' &&
                        !_hasReview) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100, // Light orange for this request
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  message.content,
                                  style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // "Confirm" Button for Lister
                            SizedBox(
                              width: 200, // Fixed width for the button
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleConfirmCompletion,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Constants.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Confirm', style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // Doer side still sees it as a regular system message
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              message.content,
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }
                  }

                  return MessageBubble(
                    message: message,
                    isMe: isMe,
                    otherUserProfilePic: otherUserProfilePic,
                    currentUserProfilePic: currentUserProfilePic,
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: _isBlockedByCurrentUser ? 'You have blocked this user.' : 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      ),
                      enabled: !_isBlockedByCurrentUser, // Disable if user is blocked
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  FloatingActionButton(
                    onPressed: _isBlockedByCurrentUser ? null : _sendMessage,
                    backgroundColor: _isBlockedByCurrentUser ? Colors.grey : Constants.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// MessageBubble is updated to pass onLocationTap
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? otherUserProfilePic;
  final String? currentUserProfilePic;
  final Function(String)? onLocationTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.otherUserProfilePic,
    this.currentUserProfilePic,
    this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    final String? profilePicUrl = isMe ? currentUserProfilePic : otherUserProfilePic;
    final bool isLocationMessage = message.type == 'location_share';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 18,
              backgroundImage: (profilePicUrl != null && profilePicUrl.isNotEmpty)
                  ? NetworkImage(profilePicUrl)
                  : const AssetImage('assets/default_profile.png') as ImageProvider,
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onTap: isLocationMessage && onLocationTap != null && message.extraData != null
                  ? () => onLocationTap!(message.content)
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: isMe ? Constants.primaryColor : Colors.grey.shade300,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isMe ? 15 : 0),
                    topRight: Radius.circular(isMe ? 0 : 15),
                    bottomLeft: const Radius.circular(15),
                    bottomRight: const Radius.circular(15),
                  ),
                ),
                padding: const EdgeInsets.all(12.0),
                margin: EdgeInsets.only(
                  left: isMe ? 50.0 : 0,
                  right: isMe ? 0 : 50.0,
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : isLocationMessage ? Colors.blue.shade800 : Colors.black87,
                        fontSize: 16.0,
                        decoration: isLocationMessage ? TextDecoration.underline : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      _formatMessageTime(message.sentAt),
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.black54,
                        fontSize: 10.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundImage: (profilePicUrl != null && profilePicUrl.isNotEmpty)
                  ? NetworkImage(profilePicUrl)
                  : const AssetImage('assets/default_profile.png') as ImageProvider,
              backgroundColor: Colors.grey.shade200,
            ),
          ],
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime sentAt) {
    // Display as-is, since backend sends +08:00
    final philippinesTime = sentAt;

    int hour = philippinesTime.hour;
    String period = 'AM';

    if (hour >= 12) {
      period = 'PM';
      if (hour > 12) {
        hour = hour - 12;
      }
    }
    if (hour == 0) {
      hour = 12;
    }

    return '${hour.toString()}:${philippinesTime.minute.toString().padLeft(2, '0')} $period';
  }
}
