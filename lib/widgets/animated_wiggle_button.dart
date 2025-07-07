import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedWiggleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final bool isAnimating;
  final Duration animationDuration;
  final double wiggleAngle;

  const AnimatedWiggleButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.isAnimating = false,
    this.animationDuration = const Duration(milliseconds: 1200), // Slower for continuous wiggle
    this.wiggleAngle = 8.0, // Slightly more angle for better visibility
  });

  @override
  State<AnimatedWiggleButton> createState() => _AnimatedWiggleButtonState();
}

class _AnimatedWiggleButtonState extends State<AnimatedWiggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _wiggleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _wiggleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Start continuous animation if isAnimating is true
    if (widget.isAnimating) {
      _startContinuousWiggle();
    }
  }

  @override
  void didUpdateWidget(AnimatedWiggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _startContinuousWiggle();
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      _stopContinuousWiggle();
    }
  }

  void _startContinuousWiggle() {
    _animationController.repeat(reverse: true);
  }

  void _stopContinuousWiggle() {
    _animationController.stop();
    _animationController.reset();
  }

  void _triggerClickWiggle() {
    // For click wiggle, we'll create a brief intense wiggle
    // Stop current animation, do a quick wiggle, then resume continuous if needed
    final wasAnimating = widget.isAnimating;
    _animationController.stop();
    _animationController.reset();
    _animationController.forward().then((_) {
      if (wasAnimating) {
        // Resume continuous wiggle after click animation
        _startContinuousWiggle();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _wiggleAnimation,
      builder: (context, child) {
        double wiggleValue;

        if (widget.isAnimating) {
          // Continuous subtle wiggle - simple sine wave
          wiggleValue = math.sin(_wiggleAnimation.value * math.pi * 2) * widget.wiggleAngle * 0.3;
        } else {
          // Click wiggle - more intense with decay
          wiggleValue = math.sin(_wiggleAnimation.value * math.pi * 6) *
                       widget.wiggleAngle *
                       (1 - _wiggleAnimation.value);
        }

        return Transform.rotate(
          angle: wiggleValue * math.pi / 180,
          child: ElevatedButton(
            onPressed: widget.onPressed != null ? () {
              // Trigger wiggle animation on click
              _triggerClickWiggle();
              // Call the original onPressed callback
              widget.onPressed!();
            } : null,
            style: widget.style,
            child: widget.child,
          ),
        );
      },
    );
  }
} 