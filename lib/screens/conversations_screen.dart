import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hanapp/viewmodels/conversations_view_model.dart';
import 'package:hanapp/models/conversation.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/screens/unified_chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ConversationsViewModel>(context, listen: false).fetchConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ConversationsViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.errorMessage != null) {
            return Center(
              child: Padding(
                padding: Constants.screenPadding,
                child: Text(
                  'Error: ${viewModel.errorMessage}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          }

          if (viewModel.conversations.isEmpty) {
            return const Center(
              child: Padding(
                padding: Constants.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                    SizedBox(height: 20),
                    Text(
                      'No conversations yet. Start a chat from a listing!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: Constants.screenPadding,
            itemCount: viewModel.conversations.length,
            itemBuilder: (context, index) {
              final conversation = viewModel.conversations[index];
              final bool isCurrentUserLister = viewModel.currentUser?.role == 'lister';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      '/unified_chat_screen',
                      arguments: {
                       // 'recipientName': conversation.otherUserName,
                      //  'recipientId': conversation.otherUserId,
                        'listingId': conversation.listingId,
                        'listingTitle': conversation.listingTitle,
                      //  'applicationId': conversation.applicationId,
                        'isLister': isCurrentUserLister,
                      },
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                         // backgroundImage: conversation.otherUserProfilePictureUrl != null && conversation.otherUserProfilePictureUrl!.isNotEmpty
                        //      ? CachedNetworkImageProvider(conversation.otherUserProfilePictureUrl!) as ImageProvider<Object>?
                         //     : null,
                         // child: (conversation.otherUserProfilePictureUrl == null || conversation.otherUserProfilePictureUrl!.isEmpty)
                        //      ? const Icon(Icons.person, size: 35)
                        //      : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text(
                              //   conversation.otherUserName,
                              //   style: const TextStyle(
                              //     fontWeight: FontWeight.bold,
                              //     fontSize: 18,
                              //   ),
                              // ),
                              if (conversation.listingTitle != null)
                                Text(
                                  'Job: ${conversation.listingTitle}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              // Text(
                              //   conversation.lastMessage ?? 'No messages yet.',
                              //   style: TextStyle(
                              //     fontSize: 14,
                              //     color: Colors.grey.shade600,
                              //   ),
                              //   maxLines: 1,
                              //   overflow: TextOverflow.ellipsis,
                              // ),
                            ],
                          ),
                        ),
                        // if (conversation.lastMessageTime != null) // Use lastMessageTime
                        //   Text(
                        //     conversation.formattedLastMessageTime,
                        //     style: TextStyle(
                        //       fontSize: 12,
                        //       color: Colors.grey.shade500,
                        //     ),
                        //   ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
