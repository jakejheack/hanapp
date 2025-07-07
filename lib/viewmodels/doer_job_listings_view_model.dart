import 'package:flutter/material.dart';
import 'package:hanapp/models/doer_listing_item.dart'; // Ensure correct path
import 'package:hanapp/utils/doer_listing_service.dart'; // Your service to fetch data
import 'package:hanapp/utils/auth_service.dart'; // NEW: Import AuthService

class DoerJobListingsViewModel extends ChangeNotifier {
  final DoerListingService _listingService = DoerListingService();
  List<DoerListingItem> _listings = []; // Stores the currently displayed listings
  bool _isLoading = false;
  String? _errorMessage;
  int? _currentDoerId; // NEW: Store current doer ID

  String _selectedCategory = 'All'; // 'All', 'Onsite', 'Hybrid', 'Remote'
  String _searchQuery = '';

  // Filter states
  double? _distanceFilter; // in km
  double? _minBudgetFilter;
  DateTime? _datePostedFilter;

  List<DoerListingItem> get listings => _listings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  // Getters for filter values (used by the filter modal to pre-fill)
  double? get distanceFilter => _distanceFilter;
  double? get minBudgetFilter => _minBudgetFilter;
  DateTime? get datePostedFilter => _datePostedFilter;

  DoerJobListingsViewModel() {
    _initializeDoerId(); // NEW: Initialize doer ID before fetching
  }

  // NEW: Initialize current doer ID
  Future<void> _initializeDoerId() async {
    try {
      final user = await AuthService.getUser();
      if (user != null) {
        _currentDoerId = user.id; // Always get the current user ID regardless of role
        debugPrint('DoerJobListingsViewModel: Current user ID: $_currentDoerId, Role: ${user.role}');
      }
      fetchJobListings(); // Fetch initial data after getting user ID
    } catch (e) {
      debugPrint('Error initializing user ID: $e');
      fetchJobListings(); // Still try to fetch even if we can't get user ID
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchJobListings(); // Trigger fetch with new search query
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    fetchJobListings(); // Trigger fetch with new category
  }

  // Method to apply all filters at once (from modal)
  void applyFilters({
    double? distance,
    double? minBudget,
    DateTime? datePosted,
  }) {
    bool changed = false;

    if (_distanceFilter != distance) {
      _distanceFilter = distance;
      changed = true;
    }
    if (_minBudgetFilter != minBudget) {
      _minBudgetFilter = minBudget;
      changed = true;
    }
    if (_datePostedFilter != datePosted) {
      _datePostedFilter = datePosted;
      changed = true;
    }

    if (changed) {
      fetchJobListings(); // Only fetch if filters actually changed
    }
  }

  Future<void> fetchJobListings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Call the service with ALL current filter parameters including current doer ID
      final response = await _listingService.getAvailableListings(
        categoryFilter: _selectedCategory,
        searchQuery: _searchQuery,
        distance: _distanceFilter,
        minBudget: _minBudgetFilter,
        datePosted: _datePostedFilter,
        currentDoerId: _currentDoerId, // NEW: Pass current doer ID
      );

      if (response['success']) {
        _listings = response['listings']; // _listings now holds the filtered data from backend
      } else {
        _errorMessage = response['message'] ?? 'Failed to fetch job listings.';
        _listings = [];
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      debugPrint('Error fetching doer job listings: $e');
      _listings = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
