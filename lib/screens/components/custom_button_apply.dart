import 'package:flutter/material.dart';

// This is a specialized CustomButton for the "Apply" action
// It explicitly handles onPressed as a Future<void> Function()?
// to avoid type mismatch errors with async callbacks.
class CustomButtonApply extends StatelessWidget {
  final String text;
  final Future<void> Function()? onPressed; // Accepts async functions or null
  final Color? color;
  final Color? textColor;
  final double borderRadius;
  final double height;
  final double? width; // Width can be optional

  const CustomButtonApply({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.textColor,
    this.borderRadius = 12.0, // Default border radius for consistency
    this.height = 50.0, // Default height for consistency
    this.width, // Optional width
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width, // Apply width if provided
      child: ElevatedButton(
        onPressed: onPressed, // This is now compatible with Future<void> Function()?
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Theme.of(context).primaryColor,
          foregroundColor: textColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: EdgeInsets.zero, // Remove default padding to control size with SizedBox
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor ?? Colors.white,
          ),
        ),
      ),
    );
  }
}
