import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import 'package:intl/intl.dart';

class DatePickerField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final Function(DateTime)? onDateSelected;

  const DatePickerField({
    super.key,
    required this.controller,
    required this.labelText,
    this.onDateSelected,
  });

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () {
        picker.DatePicker.showDatePicker(
          context,
          showTitleActions: true,
          minTime: DateTime(1900, 1, 1),
          maxTime: DateTime.now(),
          onConfirm: (date) {
            widget.controller.text = DateFormat('yyyy-MM-dd').format(date);
            widget.onDateSelected?.call(date);
          },
          currentTime: DateTime.now(),
          locale: picker.LocaleType.en,
        );
      },
    );
  }
}