// import 'package:flutter/material.dart';
// import 'package:hanapp/models/application.dart'; // Import the new Application model
// import 'package:hanapp/utils/listing_service.dart'; // For fetching application details
// import 'package:hanapp/utils/auth_service.dart'; // For current user context
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:hanapp/viewmodels/chat_view_model.dart'; // For navigating to chat
// import 'package:hanapp/screens/user_profile_screen.dart'; // For viewing applicant's full profile
// import 'package:hanapp/screens/lister/listing_details_screen.dart'; // For viewing all applicants for the listing
//
// class ApplicationOverviewScreen extends StatefulWidget {
//   final int applicationId;
//
//   const ApplicationOverviewScreen({super.key, required this.applicationId});
//
//   @override
//   State<ApplicationOverviewScreen> createState() => _ApplicationOverviewScreenState();
// }
//
// class _ApplicationOverviewScreenState extends State<ApplicationOverviewScreen> {
//   final ListingService _listingService = ListingService();
//   Application? _application;
//   bool _isLoading = true;
//   String? _errorMessage;
//   int? _currentUserId; // To check if current user is the lister
//
//   @override
//   void initState() {
//     super.initState();
//     _loadCurrentUserAndApplicationDetails();
//   }
//
//   Future<void> _loadCurrentUserAndApplicationDetails() async {
//     final currentUser = await AuthService.getUser();
//     if (currentUser == null || currentUser.id == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('User not logged in.')),
//       );
//       Navigator.of(context).pop();
//       return;
//     }
//     _currentUserId = currentUser.id;
//     _fetchApplicationDetails();
//   }
//
//   Future<void> _fetchApplicationDetails() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       final response = await _listingService.getApplicationDetails(widget.applicationId);
//       if (response['success']) {
//         setState(() {
//           _application = response['application'];
//         });
//       } else {
//         setState(() {
//           _errorMessage = response['message'] ?? 'Failed to load application details.';
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'An error occurred: $e';
//       });
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _updateApplicationStatus(String status) async {
//     if (_application == null || _currentUserId == null) return;
//
//     // The initiator of the status change is the current user (Lister)
//     final response = await _listingService.updateApplicationStatus(
//       applicationId: _application!.id,
//       status: status,
//       initiatorId: _currentUserId!,
//     );
//
//     if (response['success']) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(response['message'])),
//       );
//       // Re-fetch details to update UI with new status
//       _fetchApplicationDetails();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to update status: ${response['message']}')),
//       );
//     }
//   }
//
//   void _navigateToChat() {
//     if (_application == null || _currentUserId == null) return;
//
//     // Assuming the current user is the Lister, and the recipient is the applicant
//     Navigator.of(context).pushNamed(
//       '/unified_chat_screen',
//       arguments: {
//         'recipientId': _application!.applicant!.id,
//         'recipientName': _application!.applicant!.fullName,
//         'listingId': _application!.listing!.id,
//         'listingTitle': _application!.listing!.title,
//         'applicationId': _application!.id,
//         'isLister': true, // Lister is initiating the chat from this screen
//       },
//     );
//   }
//
//   // Navigate to the ListingDetailsScreen to see all applicants for this listing
//   void _viewAllApplicants() {
//     if (_application?.listing?.id != null) {
//       Navigator.of(context).pushNamed(
//         '/listing_details', // Assuming this route exists and can display applicants
//         arguments: _application!.listing!.id,
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Listing details not available to view applicants.')),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Determine if the current user is the lister of this listing
//     final bool isCurrentUserLister = _application?.listing?.listerId == _currentUserId;
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF141CC9),
//         foregroundColor: Colors.white,
//         title: const Text('Listing Details'), // Changed title to match image
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : _errorMessage != null
//           ? Center(child: Text(_errorMessage!))
//           : _application == null
//           ? const Center(child: Text('Application not found.'))
//           : SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Listing Title (from image)
//             Text(
//               _application!.listing!.title,
//               style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             // Amount (from image)
//             Text(
//               '₱${_application!.listing!.price.toStringAsFixed(2)}',
//               style: TextStyle(fontSize: 20, color: Colors.green.shade700, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             // Details/Description (from image)
//             Text(
//               _application!.listing!.description,
//               style: const TextStyle(fontSize: 16),
//             ),
//             const SizedBox(height: 24),
//
//             // Connect Button (from image)
//             if (isCurrentUserLister && (_application!.status == 'pending' || _application!.status == 'accepted'))
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: _navigateToChat,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF141CC9),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 15),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                   ),
//                   child: const Text('Connect', style: TextStyle(fontSize: 18)),
//                 ),
//               ),
//             const SizedBox(height: 12),
//
//             // View all applicants link (from image)
//             if (isCurrentUserLister)
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: TextButton(
//                   onPressed: _viewAllApplicants,
//                   child: const Text(
//                     'View all applicants',
//                     style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
//                   ),
//                 ),
//               ),
//             const SizedBox(height: 24),
//
//             // Applicant Section (styled like "Lister" in image)
//             const Text(
//               'Applicant Details:', // Changed from 'Applicant:' to match context
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 12),
//             Row(
//               children: [
//                 CircleAvatar(
//                   radius: 30,
//                   backgroundImage: _application!.applicant!.profilePictureUrl != null && _application!.applicant!.profilePictureUrl!.isNotEmpty
//                       ? CachedNetworkImageProvider(_application!.applicant!.profilePictureUrl!) as ImageProvider<Object>?
//                       : null,
//                   child: (_application!.applicant!.profilePictureUrl == null || _application!.applicant!.profilePictureUrl!.isEmpty)
//                       ? const Icon(Icons.person, size: 35, color: Colors.grey)
//                       : null,
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         _application!.applicant!.fullName,
//                         style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//                       ),
//                       Text(
//                         _application!.applicant!.addressDetails ?? 'Address not available',
//                         style: const TextStyle(fontSize: 14, color: Colors.grey),
//                       ),
//                       Text(
//                         'Applied on: ${DateFormat('MMMM d, yyyy').format(_application!.appliedAt)}', // Changed to applied date
//                         style: const TextStyle(fontSize: 14, color: Colors.grey),
//                       ),
//                       const SizedBox(height: 4),
//                       Row(
//                         children: [
//                           Icon(Icons.star, color: Colors.amber, size: 18),
//                           const SizedBox(width: 4),
//                           Text(
//                             _application!.applicant!.averageRating!.toStringAsFixed(1),
//                             style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
//                           ),
//                           Text(
//                             ' (${_application!.applicant!.totalReviews} reviews)',
//                             style: const TextStyle(fontSize: 12, color: Colors.grey),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 24),
//
//             // Applicant's Message (if provided during application)
//             if (_application!.message != null && _application!.message!.isNotEmpty) ...[
//               const Text(
//                 'Applicant\'s Message:',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 8),
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade100,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.grey.shade200),
//                 ),
//                 child: Text(
//                   _application!.message!,
//                   style: const TextStyle(fontSize: 15),
//                 ),
//               ),
//               const SizedBox(height: 24),
//             ],
//
//             // Section 3: Application Status & Actions (Only for Lister)
//             if (isCurrentUserLister)
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Manage Application:', // More descriptive title
//                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 12),
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                     decoration: BoxDecoration(
//                       color: _getStatusColor(_application!.status).shade100,
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Text(
//                       _getStatusText(_application!.status),
//                       style: TextStyle(
//                           color: _getStatusColor(_application!.status).shade800,
//                           fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//
//                   // Action Buttons
//                   if (_application!.status == 'pending')
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                       children: [
//                         Expanded(
//                           child: ElevatedButton(
//                             onPressed: () => _updateApplicationStatus('rejected'),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.red.shade400,
//                               foregroundColor: Colors.white,
//                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                               padding: const EdgeInsets.symmetric(vertical: 12),
//                             ),
//                             child: const Text('Reject'),
//                           ),
//                         ),
//                         const SizedBox(width: 16),
//                         Expanded(
//                           child: ElevatedButton(
//                             onPressed: () => _updateApplicationStatus('accepted'),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.green.shade400,
//                               foregroundColor: Colors.white,
//                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                               padding: const EdgeInsets.symmetric(vertical: 12),
//                             ),
//                             child: const Text('Accept'),
//                           ),
//                         ),
//                       ],
//                     ),
//                   // "Connect with Doer" or "View Chat" button
//                   if (_application!.status == 'accepted' ||
//                       _application!.status == 'hired' ||
//                       _application!.status == 'ongoing' ||
//                       _application!.status == 'completed_by_doer' ||
//                       _application!.status == 'completed')
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: _navigateToChat,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xFF141CC9),
//                           foregroundColor: Colors.white,
//                           padding: const EdgeInsets.symmetric(vertical: 15),
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                         ),
//                         child: Text(
//                           _application!.status == 'accepted' ? 'Connect with Doer' : 'View Chat',
//                           style: const TextStyle(fontSize: 18),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             const SizedBox(height: 24),
//
//             // Applicant's Reviews Section (similar to UserProfileScreen)
//             const Text(
//               'Applicant\'s Reviews:',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             if (_application!.applicant!.totalReviews == 0)
//               const Center(child: Text('No reviews yet for this applicant.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
//             else if (_application!.applicant!.reviews != null && _application!.applicant!.reviews!.isNotEmpty)
//               ListView.builder(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 itemCount: _application!.applicant!.reviews!.length,
//                 itemBuilder: (context, index) {
//                   final review = _application!.applicant!.reviews![index];
//                   return Card(
//                     margin: const EdgeInsets.only(bottom: 12.0),
//                     elevation: 2,
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               CircleAvatar(
//                                 radius: 20,
//                                 backgroundImage: review.reviewerProfilePictureUrl != null && review.reviewerProfilePictureUrl!.isNotEmpty
//                                     ? CachedNetworkImageProvider(review.reviewerProfilePictureUrl!) as ImageProvider<Object>?
//                                     : null,
//                                 child: (review.reviewerProfilePictureUrl == null || review.reviewerProfilePictureUrl!.isEmpty)
//                                     ? const Icon(Icons.person, size: 25, color: Colors.grey)
//                                     : null,
//                               ),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       review.reviewerFullName,
//                                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                                     ),
//                                     Text(
//                                       DateFormat('MMMM d, yyyy').format(review.createdAt),
//                                       style: const TextStyle(fontSize: 12, color: Colors.grey),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               Row(
//                                 children: [
//                                   Icon(Icons.star, color: Colors.amber, size: 20),
//                                   Text(
//                                     review.rating.toStringAsFixed(1),
//                                     style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 12),
//                           Text(
//                             review.comment,
//                             style: const TextStyle(fontSize: 15),
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               )
//             else
//               const Center(child: Text('Error loading reviews.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.red))),
//           ],
//         ),
//       ),
//     );
//   }
//
//   String _getStatusText(String status) {
//     switch (status) {
//       case 'pending':
//         return 'Pending';
//       case 'accepted':
//         return 'Accepted (Connect to Chat)';
//       case 'rejected':
//         return 'Rejected';
//       case 'hired':
//         return 'Hired';
//       case 'ongoing':
//         return 'Ongoing';
//       case 'completed_by_doer':
//         return 'Marked Done by Doer';
//       case 'completed':
//         return 'Completed';
//       default:
//         return 'Unknown Status';
//     }
//   }
//
//   MaterialColor _getStatusColor(String status) {
//     switch (status) {
//       case 'pending':
//         return Colors.orange;
//       case 'accepted':
//         return Colors.blue;
//       case 'rejected':
//         return Colors.red;
//       case 'hired':
//         return Colors.purple;
//       case 'ongoing':
//         return Colors.green;
//       case 'completed_by_doer':
//         return Colors.deepPurple;
//       case 'completed':
//         return Colors.teal;
//       default:
//         return Colors.grey;
//     }
//   }
// }
