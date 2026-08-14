import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'player.dart';

/// Repaints replacement images above the SVGA template sprite stack.
class SvgaReplacementOverlay extends CustomPainter {
  SvgaReplacementOverlay({
    required this.controller,
    required this.replacements,
    required this.fit,
  }) : super(repaint: controller);

  final SVGAAnimationController controller;
  final Map<String, ui.Image> replacements;
  final BoxFit fit;

  @override
  void paint(Canvas canvas, Size size) {
    final videoItem = controller.videoItem;
    if (videoItem == null || size.isEmpty) return;
    final viewBox = Size(
      videoItem.params.viewBoxWidth,
      videoItem.params.viewBoxHeight,
    );
    if (viewBox.isEmpty) return;

    final fittedSizes = applyBoxFit(fit, viewBox, size);
    final scaleX = fittedSizes.destination.width / fittedSizes.source.width;
    final scaleY = fittedSizes.destination.height / fittedSizes.source.height;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
      (size.width - viewBox.width * scaleX) / 2,
      (size.height - viewBox.height * scaleY) / 2,
    );
    canvas.scale(scaleX, scaleY);
    for (final sprite in videoItem.sprites) {
      final image = replacements[sprite.imageKey];
      if (image == null || sprite.frames.isEmpty) continue;
      final frame = sprite.frames[controller.currentFrame];
      canvas.save();
      if (frame.hasTransform()) {
        canvas.transform(
          Float64List.fromList([
            frame.transform.a,
            frame.transform.b,
            0,
            0,
            frame.transform.c,
            frame.transform.d,
            0,
            0,
            0,
            0,
            1,
            0,
            frame.transform.tx,
            frame.transform.ty,
            0,
            1,
          ]),
        );
      }
      final destination = Rect.fromLTWH(
        0,
        0,
        frame.layout.width,
        frame.layout.height,
      );
      final alpha = frame.hasAlpha() ? (frame.alpha * 255).round() : 255;
      canvas.drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        destination,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.low
          ..color = Color.fromARGB(alpha.clamp(0, 255), 0, 0, 0),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SvgaReplacementOverlay oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.replacements != replacements ||
      oldDelegate.fit != fit;
}
