import 'package:flutter/material.dart';
import 'package:hanapp/models/combined_listing_item.dart';
import 'package:hanapp/services/combined_listing_service.dart'; // Ensure this path is correct

class CombinedListingsViewModel extends ChangeNotifier {
  final CombinedListingService _service = CombinedListingService();

  List<CombinedListingItem> _allListings = [];
  List<CombinedListingItem> _activeListings = [];
  List<CombinedListingItem> _completedListings = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _totalViews = 0; // Total views
  int _totalApplicants = 0; // Total applicants

  List<CombinedListingItem> get allListings => _allListings;
  List<CombinedListingItem> get activeListings => _activeListings;
  List<CombinedListingItem> get completedListings => _completedListings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalViews => _totalViews; // Getter for total views
  int get totalApplicants => _totalApplicants; // Getter for total applicants

  Future<void> fetchCombinedListings({required int listerId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _service.fetchCombinedListings(listerId: listerId);
      if (response['success']) {
        _allListings = response['listings'];
        _activeListings = _allListings.where((listing) =>
        listing.status != 'completed' && // Exclude if explicitly completed
            listing.status != 'CANCELLED' && // Also exclude if cancelled (if you have this status)
            listing.isActive // Ensure it's marked as active by the backend
        ).toList();
        _completedListings = _allListings.where((listing) =>
        listing.status == 'completed'
        ).toList();
        _totalViews = response['total_views'] ?? 0; // Update total views
        _totalApplicants = response['total_applicants'] ?? 0; // Update total applicants
      } else {
        _errorMessage = response['message'] ?? 'Failed to fetch listings.';
        _allListings = [];
        _activeListings = [];
        _completedListings = [];
        _totalViews = 0; // Reset on error
        _totalApplicants = 0; // Reset on error
      }
    } catch (e) {
      _errorMessage = 'Error fetching combined listings: $e';
      _allListings = [];
      _activeListings = [];
      _completedListings = [];
      _totalViews = 0; // Reset on error
      _totalApplicants = 0; // Reset on error
      print('CombinedListingsViewModel Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
