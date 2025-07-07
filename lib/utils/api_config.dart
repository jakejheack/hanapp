class ApiConfig {
  // IMPORTANT: Replace with the actual URL of your Hostinger API folder.
  // Example: "https://your_domain.com/api"
  // Make sure to use HTTPS in production!
  
  // Set this to true for local development, false for production
  static const bool isLocalDevelopment = false;
  
  // Local development URL
  static const String localBaseUrl = "http://localhost/hanapp/hanapp_backend/api";
  
  // Production URL
  static const String productionBaseUrl = "https://autosell.io/api";
  
  // Use local URL if in development mode, otherwise use production URL
  static String get baseUrl {
    final url = isLocalDevelopment ? localBaseUrl : productionBaseUrl;
    print('ApiConfig: Using ${isLocalDevelopment ? "LOCAL" : "PRODUCTION"} API URL: $url');
    return url;
  }

  // Convert all endpoints to getters
  static String get registerEndpoint => "$baseUrl/register.php";
  static String get loginEndpoint => "$baseUrl/login.php";
  static String get verifyEmailEndpoint => "$baseUrl/verify_email.php";
  static String get uploadProfilePictureEndpoint => "$baseUrl/auth/upload_profile_picture.php";
  static String get updateRoleEndpoint => "$baseUrl/update_role.php";

  // NEW Listing Endpoints
  static String get createListingEndpoint => "$baseUrl/create_listing.php";
  static String get getListingsEndpoint => "$baseUrl/get_listings.php";
  static String get getListingDetailsEndpoint => "$baseUrl/get_listing_details.php";
  static String get applyToListingEndpoint => "$baseUrl/apply_to_listing.php";
  static String get getApplicantsEndpoint => "$baseUrl/get_applicants.php";
  static String get deleteListingEndpoint => "$baseUrl/delete_listing.php";
  static String get completeListingEndpoint => "$baseUrl/complete_listing.php";
  // NEW User & Review Endpoints
  static String get getUserProfileEndpoint => "$baseUrl/get_user_profile.php";
  static String get submitReviewEndpoint => "$baseUrl/reviews/submit_review.php";
  static String get getUserReviewsEndpoint => "$baseUrl/get_user_reviews.php";

  // NEW Chat Endpoints (Simplified)
  // static const String sendMessageEndpoint = "$baseUrl/send_message.php";
  // static const String getMessagesEndpoint = "$baseUrl/get_messages.php";

 // static const String getConversationsEndpoint = "$baseUrl/chat/get_conversations.php"; // NEW
  // Notification Endpoints
  static String get getNotificationsEndpoint => "$baseUrl/notifications/get_notifications.php"; // NEW
  static String get markNotificationAsReadEndpoint => "$baseUrl/notifications/mark_read.php";
  //static const String updateApplicationStatusEndpoint = "$baseUrl/listings/update_application_status.php";
  
  // Favorite Endpoints
  static String get addFavoriteEndpoint => "$baseUrl/favorite/add_favorite_user.php";
  static String get removeFavoriteEndpoint => "$baseUrl/favorite/remove_favorite.php";
  static String get getFavoritesEndpoint => "$baseUrl/favorite/get_favorite.php";

  // users block
  static String get blockUserEndpoint => "$baseUrl/user/block_user.php";
  static String get unblockUserEndpoint => "$baseUrl/user/unblock_user.php";
  static String get getBlockedUsersEndpoint => "$baseUrl/user/get_blocked_user.php";

  static String get updateUserProfileEndpoint => "$baseUrl/auth/update_profile.php";
  static String get updateProfileEndpoint => "$baseUrl/auth/update_profile.php";
  static String get updateAvailabilityEndpoint => "$baseUrl/auth/update_user_availability.php";
  static String get toggleStatusEndpoint => "$baseUrl/auth/update_user_availability.php";
  static String get getLoginHistoryEndpoint => "$baseUrl/get_login_history.php";
  static String get logLoginHistoryEndpoint => "$baseUrl/log_login_history.php";

  // Balance Endpoints (Placeholder for now, actual implementation would need backend)
  static String get getBalanceEndpoint => "$baseUrl/balance/get_balance.php"; // NEW
  static String get getTransactionsEndpoint => "$baseUrl/balance/get_transactions.php"; // NEW
  static String get cashInEndpoint => "$baseUrl/balance/cash_in.php";

  static String get updateListingEndpoint => "$baseUrl/update_listing.php"; // NEW
  static String get updateApplicationStatusEndpoint => "$baseUrl/update_application_status.php";

  static String get getConversationsEndpoint => "$baseUrl/get_conversations.php"; // NEW: Get conversations

  static String get getReviewsForUserEndpoint => "$baseUrl/rating/get_reviews_for_user.php"; // NEW: Endpoint for reviews
  static String get getApplicationDetailsEndpoint => "$baseUrl/get_application_details.php"; // NEW: Endpoint for application details
  // static const String verifyEmailEndpoint = '$baseUrl/verify_email.php'; // NEW
  static String get resendVerificationCodeEndpoint => '$baseUrl/resend_verification_code.php'; // NEW

  static String get socialLoginCheckEndpoint => '$baseUrl/social_login_check.php';

  //asap listing api
  static String get createAsapListingEndpoint => "$baseUrl/asap_listings/create_asap_listing.php";
  static String get getAsapListingDetailsEndpoint => '$baseUrl/asap_listings/get_asap_listing_details.php';
  static String get updateAsapListingEndpoint => '$baseUrl/asap_listings/update_asap_listing.php'; // NEW
  static String get deleteAsapListingEndpoint => '$baseUrl/asap_listings/delete_asap_listing.php'; // NEW
  static String get updateAsapListingStatusEndpoint => '$baseUrl/asap_listings/update_asap_listing_status.php'; // NEW

  //public listing api
  static String get createPublicListingEndpoint => "$baseUrl/public_listing/create_listing.php";
  static String get getPublicListingEndpoint => "$baseUrl/public_listing/get_listing_details.php";
  static String get publicUpdateListingEndpoint => '$baseUrl/public_listing/update_listing.php'; // NEW
  static String get publicDeleteListingEndpoint => '$baseUrl/public_listing/delete_listing.php'; // NEW
  static String get updateListingStatusEndpoint => '$baseUrl/public_listing/update_application_status.php'; // NEW

  static String get getCombinedListingsEndpoint => "$baseUrl/combined_lister/get_combined_listings.php";

  //getlistingapplicant
  static String get getListingApplicantsEndpoint => '$baseUrl/applications/get_listing_applicants.php'; // NEW

  // NEW: Doer Listing Endpoints
  static String get getAvailableListingsEndpoint => '$baseUrl/doer/get_available_listings.php';
  static String get createApplicationEndpoint => '$baseUrl/applications/apply_for_job.php';

  static String get incrementViewEndpoint => '$baseUrl/combined_lister/increment_view.php'; // NEW
  static String get updateUserAvailabilityEndpoint => '$baseUrl/auth/update_user_availability.php';

  static String get submitVerificationEndpoint => '$baseUrl/verification/submit_verification.php';
  static String get changePasswordEndpoint => '$baseUrl/auth/change_password.php'; // NEW

  // NEW: Financial Endpoints
  static String get getUserFinancialDetailsEndpoint => '$baseUrl/user/get_user_financial_details.php'; // For total profit and verification
  static String get submitWithdrawalEndpoint => '$baseUrl/finance/submit_withdrawal.php';
  static String get getWithdrawalHistoryEndpoint => '$baseUrl/finance/get_withdrawal_history.php'; // Fixed: Using corrected version

  static String get getUserEndpoint => '$baseUrl/auth/get_user.php';
  static String get getUserReviewsLatestEndpoint => '$baseUrl/reviews/get_user_reviews.php';

  // NEW: Chat Endpoints
  static String get createConversationEndpoint => '$baseUrl/chat/create_conversation.php';
  static String get sendMessageEndpoint => '$baseUrl/chat/send_message.php';
  static String get getMessagesEndpoint => '$baseUrl/chat/get_messages.php';
  static String get getConversationDetailsEndpoint => '$baseUrl/chat/get_conversation_details.php';
  static String get getUserConversationsEndpoint => '$baseUrl/chat/get_user_conversations.php';
  // Doer Job Endpoints
  static String get getDoerJobListingsEndpoint => '$baseUrl/doer_jobs/get_doer_job_listings.php';
  static String get markApplicationCompleteEndpoint => '$baseUrl/doer_jobs/mark_application_complete.php';
  static String get cancelApplicationEndpoint => '$baseUrl/doer_jobs/cancel_application.php';

  static String get createXenditPaymentEndpoint => '$baseUrl/finance/create_xendit_payment.php';
  static String get startProjectEndpoint => '$baseUrl/doer_jobs/start_project.php'; // NEW ENDPOINT

  static String get sendPasswordResetEmailEndpoint => "$baseUrl/send_password_reset_email.php";
  static String get verifyPasswordResetCodeEndpoint => "$baseUrl/verify_password_reset_code.php";
  static String get resetPasswordWithCodeEndpoint => "$baseUrl/reset_password_with_code.php";
  static String get debugPasswordResetEndpoint => "$baseUrl/debug_password_reset.php";

  static String get getDoerNotificationsEndpoint => "${baseUrl}/notifications/get_doer_notifications.php";
  static String get createDoerNotificationEndpoint => "${baseUrl}/notifications/create_doer_notification.php";
  static String get getUnreadCountEndpoint => "${baseUrl}/notifications/get_unread_count.php";

  // NEW: ASAP Flow Endpoints
  static String get searchDoersEndpoint => "${baseUrl}/asap/search_doers.php";
  static String get selectDoerEndpoint => "${baseUrl}/asap/select_doer.php";
  static String get convertToPublicEndpoint => "${baseUrl}/asap/convert_to_public.php";

  // NEW: User Status Verification Endpoint
  static String get checkUserStatusEndpoint => "${baseUrl}/check_user_status.php";

  // NEW: Social Login Completion Endpoint
  static String get completeSocialRegistrationEndpoint => "${baseUrl}/auth/complete_social_registration.php";
}