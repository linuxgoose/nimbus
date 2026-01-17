import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Converts a Flutter IconData to a PNG image file for use in Android widgets
class IconToImage {
  /// Renders an icon to a PNG file with the specified color and size
  /// Returns the file path of the generated image
  static Future<String> saveIconAsPng({
    required IconData icon,
    required Color color,
    required String filename,
    double size = 96.0,
  }) async {
    // Create a canvas to draw the icon
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the icon using TextPainter
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    // Save to file
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);

    return file.path;
  }

  /// Generates all weather icons needed for widgets with the specified color
  static Future<void> generateAllWeatherIcons({
    required Color iconColor,
  }) async {
    // This will be called by the widget update function
    // Icons will be generated on-demand based on weather conditions
  }
}
