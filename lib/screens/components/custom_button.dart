// lib/screens/components/custom_button.dart
import 'package:flutter/material.dart';
import 'package:hanapp/utils/constants.dart'; // Assuming constants.dart exists

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final Color textColor;
  final double? width;
  final double height;
  final double borderRadius;
  final BorderSide? borderSide; // For outlined buttons
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.textColor = buttonTextColor, // Default white for primary buttons
    this.width,
    this.height = 50.0,
    this.borderRadius = 8.0,
    this.borderSide,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity, // Default to full width
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? primaryColor, // Use primaryColor as default
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: borderSide ?? BorderSide.none, // Apply border if provided
          ),
          elevation: 0, // No shadow for a flat look
          padding: EdgeInsets.zero, // Control padding via SizedBox height
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}