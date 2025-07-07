import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:hanapp/utils/constants.dart' as Constants; // Your constants

class DoerJobFilterModal extends StatefulWidget {
  final double? initialDistance;
  final double? initialMinBudget;
  final DateTime? initialDatePosted;

  const DoerJobFilterModal({
    super.key,
    this.initialDistance,
    this.initialMinBudget,
    this.initialDatePosted,
  });

  @override
  State<DoerJobFilterModal> createState() => _DoerJobFilterModalState();
}

class _DoerJobFilterModalState extends State<DoerJobFilterModal> {
  double _currentDistance = 1.0; // Default 1km
  final TextEditingController _minBudgetController = TextEditingController();
  DateTime? _selectedDatePosted;

  @override
  void initState() {
    super.initState();
    _currentDistance = widget.initialDistance ?? 1.0;
    _minBudgetController.text = (widget.initialMinBudget ?? '').toString();
    _selectedDatePosted = widget.initialDatePosted;
  }

  @override
  void dispose() {
    _minBudgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDatePosted ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Constants.primaryColor, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Constants.textColor, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Constants.primaryColor, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDatePosted) {
      setState(() {
        _selectedDatePosted = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Filter Listings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Constants.textColor,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () {
              Navigator.of(context).pop(); // Close without applying filters
            },
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            Slider(
              value: _currentDistance,
              min: 1.0,
              max: 100.0,
              divisions: 99, // 1km to 100km
              label: '${_currentDistance.round()} km',
              activeColor: Constants.primaryColor,
              inactiveColor: Constants.primaryColor.withOpacity(0.3),
              onChanged: (double value) {
                setState(() {
                  _currentDistance = value;
                });
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_currentDistance.round()} km',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Budget (minimum)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _minBudgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter Minimum Budget here',
                prefixText: '₱',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Constants.primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Date Posted',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDatePosted == null
                          ? 'Select Date'
                          : DateFormat('MMMM d, yyyy').format(_selectedDatePosted!),
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDatePosted == null ? Colors.grey : Constants.textColor,
                      ),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text(
            'Reset',
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
          onPressed: () {
            setState(() {
              _currentDistance = 1.0;
              _minBudgetController.clear();
              _selectedDatePosted = null;
            });
          },
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Constants.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text(
            'Apply Filters',
            style: TextStyle(fontSize: 16),
          ),
          onPressed: () {
            Navigator.of(context).pop({
              'distance': _currentDistance,
              'minBudget': double.tryParse(_minBudgetController.text),
              'datePosted': _selectedDatePosted,
            });
          },
        ),
      ],
    );
  }
}
