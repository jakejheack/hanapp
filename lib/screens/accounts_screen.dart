import 'package:flutter/material.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/user_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hanapp/services/api_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/utils/image_utils.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  User? _currentUser;
  List<User> _favoriteUsers = [];
  List<User> _blockedUsers = [];
  bool _isLoadingFavorites = true;
  bool _isLoadingBlocked = true;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndAccounts();
  }

  Future<void> _loadCurrentUserAndAccounts() async {
    _currentUser = await AuthService.getUser();
    if (_currentUser == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    await _fetchFavorites();
    await _fetchBlockedUsers();
  }

  Future<void> _fetchFavorites() async {
    if (_currentUser == null) return;
    setState(() { _isLoadingFavorites = true; });
    final response = await _userService.getFavorites(_currentUser!.id);
    setState(() {
      _isLoadingFavorites = false;
      if (response['success']) {
        _favoriteUsers = response['favorites'];
      } else {
        _showSnackBar('Failed to load favorites: ${response['message']}', isError: true);
      }
    });
  }

  Future<void> _fetchBlockedUsers() async {
    if (_currentUser == null) return;
    setState(() { _isLoadingBlocked = true; });
    final response = await _userService.getBlockedUsers(_currentUser!.id);
    setState(() {
      _isLoadingBlocked = false;
      if (response['success']) {
        _blockedUsers = response['blocked_users'];
      } else {
        _showSnackBar('Failed to load blocked users: ${response['message']}', isError: true);
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _removeFavorite(User userToRemove) async {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove from Favorites?'),
          content: Text('Are you sure you want to remove ${userToRemove.fullName} from your favorite lists?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final response = await _userService.removeFavorite(_currentUser!.id, userToRemove.id);
      if (response['success']) {
        _showSnackBar('${userToRemove.fullName} removed from favorites.');
        _fetchFavorites(); // Refresh the list
      } else {
        _showSnackBar('Failed to remove from favorites: ${response['message']}', isError: true);
      }
    }
  }

  Future<void> _unblockUser(User userToUnblock) async {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unblock User?'),
          content: Text('Are you sure you want to unblock ${userToUnblock.fullName}?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final response = await _userService.unblockUser(_currentUser!.id, userToUnblock.id);
      if (response['success']) {
        _showSnackBar('${userToUnblock.fullName} unblocked.');
        _fetchBlockedUsers(); // Refresh the list
      } else {
        _showSnackBar('Failed to unblock user: ${response['message']}', isError: true);
      }
    }
  }

  Widget _buildUserListTile(User user, {required String actionText, required VoidCallback onAction}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: ImageUtils.createProfileImageProvider(user.profilePictureUrl),
          child: (user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty)
              ? const Icon(Icons.person, size: 24, color: Colors.white)
              : null,
        ),
        title: Text(user.fullName),
        subtitle: Text(user.email),
        trailing: TextButton(
          onPressed: onAction,
          child: Text(
            actionText,
            style: TextStyle(color: actionText == 'Remove' ? Colors.red : Colors.green),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Favorite Accounts Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Favorite accounts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _isLoadingFavorites
                      ? const Center(child: CircularProgressIndicator())
                      : _favoriteUsers.isEmpty
                      ? const Text('No favorite accounts yet.')
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _favoriteUsers.length,
                    itemBuilder: (context, index) {
                      final user = _favoriteUsers[index];
                      return _buildUserListTile(
                        user,
                        actionText: 'Remove',
                        onAction: () => _removeFavorite(user),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            // Blocked Accounts Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Blocked accounts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _isLoadingBlocked
                      ? const Center(child: CircularProgressIndicator())
                      : _blockedUsers.isEmpty
                      ? const Text('No blocked accounts yet.')
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _blockedUsers.length,
                    itemBuilder: (context, index) {
                      final user = _blockedUsers[index];
                      return _buildUserListTile(
                        user,
                        actionText: 'Unblock',
                        onAction: () => _unblockUser(user),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}