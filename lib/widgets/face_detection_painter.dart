import 'package:flutter/material.dart';

// A custom painter for the face detection circle/frame (placeholder)
class FaceDetectionPainter extends CustomPainter {
  final bool faceDetected;

  FaceDetectionPainter({required this.faceDetected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = faceDetected ? Colors.green : Colors.red
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw the main circle (as seen in the image)
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.4;
    canvas.drawCircle(center, radius, paint);

    // Draw the corner brackets
    final cornerLength = radius * 0.3;
    final halfWidth = size.width / 2;
    final halfHeight = size.height / 2;

    // Top-left
    canvas.drawLine(
      Offset(halfWidth - radius, halfHeight - radius + cornerLength),
      Offset(halfWidth - radius, halfHeight - radius),
      paint,
    );
    canvas.drawLine(
      Offset(halfWidth - radius + cornerLength, halfHeight - radius),
      Offset(halfWidth - radius, halfHeight - radius),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(halfWidth + radius, halfHeight - radius + cornerLength),
      Offset(halfWidth + radius, halfHeight - radius),
      paint,
    );
    canvas.drawLine(
      Offset(halfWidth + radius - cornerLength, halfHeight - radius),
      Offset(halfWidth + radius, halfHeight - radius),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(halfWidth - radius, halfHeight + radius - cornerLength),
      Offset(halfWidth - radius, halfHeight + radius),
      paint,
    );
    canvas.drawLine(
      Offset(halfWidth - radius + cornerLength, halfHeight + radius),
      Offset(halfWidth - radius, halfHeight + radius),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(halfWidth + radius, halfHeight + radius - cornerLength),
      Offset(halfWidth + radius, halfHeight + radius),
      paint,
    );
    canvas.drawLine(
      Offset(halfWidth + radius - cornerLength, halfHeight + radius),
      Offset(halfWidth + radius, halfHeight + radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; // Only repaint if properties change
  }
}
