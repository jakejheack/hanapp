import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Add this import for kDebugMode
import 'package:hanapp/models/user.dart'; // Make sure this path is correct
import 'package:hanapp/screens/conversations_screen.dart';
import 'package:hanapp/screens/lister/combined_listing_form_screen.dart';
import 'package:hanapp/screens/wallet_details_screen.dart';
import 'package:hanapp/utils/auth_service.dart'; // Make sure this path is correct
import 'package:hanapp/viewmodels/chat_view_model.dart';
import 'package:hanapp/viewmodels/combined_listings_view_model.dart';
import 'package:hanapp/viewmodels/conversations_view_model.dart';
import 'package:hanapp/viewmodels/doer_job_listings_view_model.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hanapp/firebase_options.dart';
import 'package:hanapp/models/user.dart'; // Make sure you import your User model
import 'package:hanapp/utils/auth_service.dart'; // Make sure you import AuthService
import 'package:hanapp/services/google_auth_service.dart'; // NEW: Import Google Auth Service
import 'package:hanapp/utils/google_signin_debug.dart'; // NEW: Import debug utility
import 'package:hanapp/services/app_lifecycle_service.dart'; // NEW: Import AppLifecycleService
// Import all your existing screens
import 'package:hanapp/screens/choose_listing_type_screen.dart';
import 'package:hanapp/screens/splash_screen.dart'; // Ensure this is your custom splash screen
import 'package:hanapp/screens/wrapper_with_verification.dart'; // Import new wrapper
import 'package:hanapp/screens/auth/login_screen.dart';
import 'package:hanapp/screens/auth/signup_screen_1.dart';
import 'package:hanapp/screens/auth/signup_screen_2.dart';
import 'package:hanapp/screens/auth/signup_screen_3.dart';
import 'package:hanapp/screens/auth/signup_screen_4.dart';
import 'package:hanapp/screens/auth/email_verification_screen.dart';
import 'package:hanapp/screens/auth/profile_picture_upload_screen.dart';
import 'package:hanapp/screens/role_selection_screen.dart';
import 'package:hanapp/screens/dashboard_screen.dart'; // This might become a placeholder or a wrapper
import 'package:hanapp/screens/lister/lister_dashboard_screen.dart'; // Your Lister/Owner Dashboard
import 'package:hanapp/screens/lister/job_listing_screen.dart';
import 'package:hanapp/screens/lister/listing_details_screen.dart';
import 'package:hanapp/screens/lister/enter_listing_details_screen.dart';
import 'package:hanapp/screens/doer/doer_dashboard_screen.dart'; // Your Doer Dashboard
import 'package:hanapp/screens/view_profile_screen.dart';
import 'package:hanapp/screens/chat_screen.dart';
import 'package:hanapp/screens/lister/anap_listing_map_screen.dart';
import 'package:hanapp/screens/lister/confirm_job_screen.dart';
import 'package:hanapp/screens/lister/rate_job_screen.dart';
import 'package:hanapp/screens/notifications_screen.dart';
import 'package:hanapp/screens/auth/select_location_on_map_screen.dart';
import 'package:hanapp/screens/lister/awaiting_listing_screen.dart';
import 'package:hanapp/screens/profile_settings_screen.dart';
import 'package:hanapp/screens/accounts_screen.dart';
import 'package:hanapp/screens/lister/enter_asap_listing_details_screen.dart';
import 'package:hanapp/screens/community_screen.dart';
import 'package:hanapp/screens/edit_profile_screen.dart';
import 'package:hanapp/screens/hanapp_balance_screen.dart';
import 'package:hanapp/screens/chat_screen_doer.dart'; // NEW: Chat Screen for Doer
import 'package:hanapp/screens/unified_chat_screen.dart'; // NEW: Unified Chat Screen
import 'package:hanapp/viewmodels/review_view_model.dart'; // Make sure this path is correct
import 'package:hanapp/screens/review_screen.dart'; // If you still have this, otherwise remove
import 'package:hanapp/screens/application_details_screen.dart'; // NEW: Import ApplicationDetailsScreen
import 'package:hanapp/screens/map_screen.dart'; // Assuming you have this
import 'package:hanapp/screens/notifications_screen.dart'; // Assuming you have this
import 'package:hanapp/screens/user_profile_screen.dart'; // Assuming you have a user profile screen
import 'package:hanapp/screens/lister/application_overview_screen.dart';
import 'package:hanapp/screens/auth/register_screen.dart';


// NEW ASAP Listing Screens
import 'package:hanapp/screens/lister/asap_listing_form_screen.dart';
import 'package:hanapp/screens/lister/asap_listing_details_screen.dart';
import 'package:hanapp/screens/lister/asap_listing_searching_screen.dart';
import 'package:hanapp/screens/lister/asap_listing_connect_screen.dart';

// NEW Public Listing Screens
import 'package:hanapp/screens/lister/public_listing_form_screen.dart';
import 'package:hanapp/screens/lister/public_listing_details_screen.dart';

import 'package:hanapp/screens/lister/combined_listings_screen.dart'; // NEW: Import CombinedListingsScreen
import 'package:hanapp/screens/doer/doer_job_listings_screen.dart'; // NEW: Import DoerJobListingsScreen
import 'package:hanapp/screens/verification_screen.dart'; // Verification Screen
import 'package:hanapp/screens/security_screen.dart'; // Security Screen
import 'package:hanapp/screens/doer/withdrawal_screen.dart'; // NEW: Withdrawal Screen
import 'package:hanapp/screens/chat_screenv2.dart'; // NEW: ChatScreen
import 'package:hanapp/screens/all_reviews_screen.dart'; // NEW: All Reviews Screen

import 'package:hanapp/screens/doer/doer_job_listings_mark_screen.dart'; // NEW: DoerJobListingsScreen
// NEW: Import the new form screens
import 'package:hanapp/screens/doer/mark_job_complete_form_screen.dart';
import 'package:hanapp/screens/doer/cancel_job_application_form_screen.dart';

import 'package:hanapp/screens/doer/balance_screen.dart'; // Ensure BalanceScreen is imported
import 'package:hanapp/screens/doer/xendit_payment_details_screen.dart';
import 'package:hanapp/screens/chat_list_screen.dart';
import 'package:hanapp/screens/because_screen.dart'; // NEW: Import WalletScreen
import 'package:hanapp/widgets/notification_wrapper.dart'; // NEW: Import NotificationWrapper
import 'package:hanapp/screens/payment_screen.dart'; // NEW: Import PaymentScreen
import 'package:hanapp/screens/payment_demo_screen.dart'; // NEW: Import PaymentDemoScreen

// NEW ASAP Flow Screens
import 'package:hanapp/screens/lister/asap_doer_search_screen.dart';
import 'package:hanapp/screens/lister/asap_doer_connect_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with proper error handling
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('Firebase initialized successfully');
    } else {
      print('Firebase already initialized, using existing instance');
    }
  } catch (e) {
    if (e.toString().contains('duplicate-app') || e.toString().contains('already exists')) {
      print('Firebase already initialized, continuing...');
    } else {
      print('Failed to initialize Firebase: $e');
    }
  }
  
  // Initialize Google Sign-In service
  try {
    await GoogleAuthService.initialize();
    print('Google Sign-In service initialized successfully');
  } catch (e) {
    print('Failed to initialize Google Sign-In service: $e');
  }
  
  // Initialize App Lifecycle Service
  try {
    await AppLifecycleService.instance.initialize();
    print('App Lifecycle Service initialized successfully');
  } catch (e) {
    print('Failed to initialize App Lifecycle Service: $e');
  }

  // Print Facebook Key Hash for development (only in debug mode)
  if (kDebugMode) {
    try {
      await AuthService.printFacebookKeyHash();
    } catch (e) {
      print('Failed to print Facebook key hash: $e');
    }
  }
  
  // Debug Google Sign-In configuration (only in debug mode)
  if (kDebugMode) {
    print('=== Starting Google Sign-In Debug ===');
    await GoogleSignInDebug.debugConfiguration();
    GoogleSignInDebug.printSHA1Fingerprints();
    GoogleSignInDebug.printTroubleshootingSteps();
    print('=== Google Sign-In Debug Complete ===');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatViewModel()),
        ChangeNotifierProvider(create: (_) => ConversationsViewModel()),
        ChangeNotifierProvider(create: (_) => ReviewViewModel()),
        ChangeNotifierProvider(create: (_) => CombinedListingsViewModel()),
        ChangeNotifierProvider(create: (_) => DoerJobListingsViewModel()),
        // Add other ViewModels here if you have them
      ],
      child: const MyApp(),
    ),
  );
}
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Register for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // This line removes the native splash screen as soon as your Flutter app
    // starts rendering its first widget (which is your SplashScreen).
    // The actual delay for content display and navigation is handled within SplashScreen.
    FlutterNativeSplash.remove();
  }

  @override
  void dispose() {
    // Unregister from app lifecycle changes
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle changes through the service
    AppLifecycleService.instance.handleAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HANAPP',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF141CC9), // HANAPP Blue
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141CC9),
          foregroundColor: Colors.white, // Set app bar text/icon color
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF141CC9), // HANAPP Blue for buttons
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF141CC9), // HANAPP Blue for text buttons
          ),
        ),
      ),
      // Set your custom SplashScreen as the initial screen of your application.
      // This means SplashScreen will be built and displayed immediately after
      // the native splash screen disappears.
      home: const SplashScreen(),
      // Keep your existing routes for named navigation within the app
      routes: {
        // Remove '/' from here as `home` property handles the initial route
        '/splash': (context) => const SplashScreen(), // If you want to navigate back to splash via route name
        '/login': (context) => const LoginScreen(),
        '/signup1': (context) => const SignupScreen1(),
        '/signup2': (context) => const SignupScreen2(),
        '/signup3': (context) => const SignupScreen3(),
        '/signup4': (context) => const SignupScreen4(),
        '/email_verification': (context) => const EmailVerificationScreen(email: ''),
        '/profile_picture_upload': (context) => const ProfilePictureUploadScreen(),
        '/role_selection': (context) => const RoleSelectionScreen(),
        '/dashboard': (context) => const DashboardScreen(), // This route might be deprecated or used as a generic base if needed
        '/lister_dashboard': (context) => const ListerDashboardScreen(),
        '/doer_dashboard': (context) => const DoerDashboardScreen(),
        '/job_listings': (context) => const JobListingScreen(),
        '/listing_details': (context) => const ListingDetailsScreen(),
        '/enter_listing_details': (context) => const EnterListingDetailsScreen(),
        // '/view_profile': (context) => const ViewProfileScreen(),
        '/anap_listing_map': (context) => const AnapListingMapScreen(),
        '/confirm_job': (context) => const ConfirmJobScreen(),
        '/rate_job': (context) => const RateJobScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/select_location_on_map': (context) => const SelectLocationOnMapScreen(),
        '/awaiting_listing': (context) => const AwaitingListingScreen(),
        '/choose_listing_type': (context) => const ChooseListingTypeScreen(),
        '/profile_settings': (context) => const ProfileSettingsScreen(),
        '/accounts': (context) => const AccountsScreen(),
        '/enter_asap_listing_details': (context) => const EnterAsapListingDetailsScreen(),
        '/community': (context) => const CommunityScreen(),
        '/edit_profile': (context) => const EditProfileScreen(),
        '/hanapp_balance': (context) => const HanAppBalanceScreen(),
        '/BecauseScreen': (context) => const BecauseScreen(),
        '/WalletDetailsScreen': (context) => const WalletDetailsScreen(),

        // Add the route for asap_listing as per the previous suggestion if it's separate from enter_asap_listing_details
        //'/asap_listing': (context) => const AsapListingScreen(),
        // '/chat_screen': (context) => const ChatScreen(), // NEW: Route for Chat Screen
        // '/chat_screen_doer': (context) => const ChatScreenDoer(), // NEW: Route for Chat Screen (Doer)
        // '/unified_chat_screen': (context) => ChangeNotifierProvider(
        //   create: (context) => ChatViewModel(),
        //   child: const UnifiedChatScreen(),
        // ),
        '/conversations_screen': (context) => ChangeNotifierProvider(
          create: (context) => ConversationsViewModel(),
          child: const ConversationsScreen(),
        ),
        '/chat_list': (context) => ChatListScreen(),
        '/notifications_screen': (context) => const NotificationsScreen(),
        '/user_profile': (context) => const UserProfileScreen(userId: 0), // Example, adjust if UserProfileScreen needs args
        '/doer_job_listings_mark': (context) => const DoerJobListingsScreenMark(),
        '/doer_job_listings': (context) => const DoerJobListingsScreen(),
        // NEW ROUTE: For Application Details
        '/application_details_screen': (context) => const ApplicationDetailsScreen(listingId: 0), // Dummy listingId, it will be overridden by MaterialPageRoute
        '/application_details': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final int applicationId = args?['applicationId'] ?? 0;
          final String listingTitle = args?['listingTitle'] ?? 'Application';
          if (applicationId == 0) {
            return const Scaffold(body: Center(child: Text('Error: Application ID not provided.')));
          }
          return ApplicationDetailsScreen(listingId: applicationId);
        },
        '/map_screen': (context) => const MapScreen(latitude: 0, longitude: 0, title: 'Location'), // Example, adjust if MapScreen needs args
        // '/application_overview_screen': (context) => const ApplicationOverviewScreen(applicationId: 0),
        '/register': (context) => const RegisterScreen(),
        // NEW ASAP Listing Routes (using 'asap_listing_id' for clarity)
        '/asap_listing_form': (context) => const AsapListingFormScreen(),
        '/asap_listing_details': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final int asapListingId = args?['listing_id'] ?? 0; // Use listing_id from args
          if (asapListingId == 0) {
            return const Scaffold(body: Center(child: Text('Error: ASAP Listing ID not provided.')));
          }
          return AsapListingDetailsScreen(listingId: asapListingId);
        },
        '/asap_listing_searching': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final int asapListingId = args?['listing_id'] ?? 0; // Use listing_id from args
          if (asapListingId == 0) {
            return const Scaffold(body: Center(child: Text('Error: ASAP Listing ID not provided.')));
          }
          return AsapListingSearchingScreen(asapListingId: asapListingId);
        },
        '/asap_listing_connect': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final int asapListingId = args?['listing_id'] ?? 0; // Use listing_id from args
          final String doerName = args?['doer_name'] ?? 'Unknown Doer';
          final String? doerProfilePic = args?['doer_profile_pic'];

          if (asapListingId == 0) {
            return const Scaffold(body: Center(child: Text('Error: ASAP Listing ID not provided.')));
          }
          return AsapListingConnectScreen(
            asapListingId: asapListingId,
            doerName: doerName,
            doerProfilePic: doerProfilePic,
          );
        },
        // NEW ASAP Flow Routes
        '/asap_doer_search': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return AsapDoerSearchScreen(
            listingId: args?['listing_id'] ?? 0,
            listingLatitude: args?['listing_latitude'] ?? 0.0,
            listingLongitude: args?['listing_longitude'] ?? 0.0,
            preferredDoerGender: args?['preferred_doer_gender'] ?? 'Any',
            maxDistance: args?['max_distance'] ?? 10.0,
          );
        },
        '/asap_doer_connect': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return AsapDoerConnectScreen(
            listingId: args?['listing_id'] ?? 0,
            listingTitle: args?['listing_title'] ?? 'ASAP Task',
            doerName: args?['doer_name'] ?? 'Unknown Doer',
            doerProfilePic: args?['doer_profile_pic'],
            doerId: args?['doer_id'],
            applicationId: args?['application_id'],
            conversationId: args?['conversation_id'],
          );
        },
        // NEW Public Listing Routes (replacing old /listing_details for form)
        '/public_listing_form': (context) => const PublicListingFormScreen(), // New route for the form
        '/public_listing_details': (context) { // New route for details
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final int listingId = args?['listing_id'] ?? 0;
          if (listingId == 0) {
            return const Scaffold(body: Center(child: Text('Error: Public Listing ID not provided.')));
          }
          return PublicListingDetailsScreen(listingId: listingId, applicationId: 0,);
        },
        // Public Listing Details Route (form route replaced by combined)
        '/combined_listings_display': (context) => const CombinedListingsScreen(),
        // NEW: Doer Job Listings Screen Route
        // '/doer_job_listings': (context) => const DoerJobListingsScreen(),
        '/combined_listing_form': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return CombinedListingFormScreen(
            listingId: args?['listing_id'],
            listingType: args?['listing_type'],
          );
        },
        '/verification': (context) => const VerificationScreen(),
        '/security': (context) => const SecurityScreen(),
        '/withdrawal': (context) => const WithdrawalScreen(),
        '/balance': (context) => const BalanceScreen(),
        '/payment_demo': (context) => const PaymentDemoScreen(),


        // '/chat_screen': (context) {
        //   // Retrieve arguments passed via Navigator.pushNamed(context, '/chat_screen', arguments: {...})
        //   final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        //
        //   // Perform null and type checks for safety
        //   if (args == null ||
        //       !args.containsKey('conversationId') ||
        //       !args.containsKey('otherUserId') ||
        //       !args.containsKey('listingTitle') ||
        //       !args.containsKey('applicationId')) {
        //     // Handle error if arguments are missing or malformed
        //     return const Scaffold(
        //         body: Center(child: Text('Error: Missing chat arguments.')));
        //   }
        //
        //   // Return the ChatScreen with all required arguments
        //   return ChatScreen(
        //     conversationId: args['conversationId'] as int,
        //     otherUserId: args['otherUserId'] as int,
        //     listingTitle: args['listingTitle'] as String,
        //     applicationId: args['applicationId'] as int, // Dynamically passing the application ID
        //   );
        // },

      },
      onGenerateRoute: (settings) {

        if (settings.name == '/view_profile') {
          final args = settings.arguments as int; // Expecting userId as int
          return MaterialPageRoute(
            builder: (context) {
              return ViewProfileScreen(userId: args);
            },
          );
        }
        // if (settings.name == '/chat') {
        //   final args = settings.arguments as Map<String, dynamic>;
        //   return MaterialPageRoute(
        //     builder: (context) {
        //       return ChatScreen(
        //         conversationId: args['conversationId'] as int,
        //         otherUserId: args['otherUserId'] as int,
        //         listingTitle: args['listingTitle'] as String, applicationId: 0,
        //       );
        //     },
        //   );
        // }
        if (settings.name == '/xendit_payment_details') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) {
              return XenditPaymentDetailsScreen(
                paymentDetails: args,
              );
            },
          );
        }

        if (settings.name == '/payment') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) {
              return PaymentScreen(
                amount: args['amount'] as double,
                user: args['user'] as User,
              );
            },
          );
        }
        // Handle other unknown routes
        final args = settings.arguments as Map<String, dynamic>?;

        switch (settings.name) {
        // ... other routes

          case '/chat_screen':
            if (args != null) {
              final bool isLister = args['isLister'] as bool? ?? false; // Default to false if not provided
              final int? applicationId = args['applicationId'] as int?; // Make applicationId optional

              return MaterialPageRoute(
                builder: (context) {
                  return ChatScreen(
                    conversationId: args['conversationId'] as int,
                    otherUserId: args['otherUserId'] as int,
                    listingTitle: args['listingTitle'] as String,
                    applicationId: applicationId ?? 0, // Use 0 if not provided
                    isLister: isLister, // <--- Pass the isLister flag here
                  );
                },
              );
            }
            return MaterialPageRoute(builder: (context) => const Text('Error: Chat arguments missing.'));

          default:
            return MaterialPageRoute(builder: (context) => const Text('Error: Unknown route'));
        }
      },

    );
  }
}

