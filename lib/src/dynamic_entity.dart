import 'dart:ui' as ui show Image;

import 'package:flutter/painting.dart';
import 'package:http/http.dart';

typedef SVGACustomDrawer = Function(Canvas canvas, int frameIndex);

class SVGADynamicEntity {
  final Map<String, bool> dynamicHidden = {};
  final Map<String, ui.Image> dynamicImages = {};
  final Map<String, TextPainter> dynamicText = {};
  final Map<String, SVGACustomDrawer> dynamicDrawer = {};
  final Set<ui.Image> _ownedImages = Set<ui.Image>.identity();

  void setHidden(bool value, String forKey) {
    dynamicHidden[forKey] = value;
  }

  /// Sets an externally owned image. Callers remain responsible for disposing it.
  ///
  /// Use [setImageWithUrl] for a library-owned image that is released by
  /// [reset].
  void setImage(ui.Image image, String forKey) {
    _replaceImage(image, forKey, ownsImage: false);
  }

  void _replaceImage(ui.Image image, String forKey, {required bool ownsImage}) {
    final previous = dynamicImages[forKey];
    if (previous != null &&
        !identical(previous, image) &&
        _ownedImages.remove(previous)) {
      previous.dispose();
    }
    dynamicImages[forKey] = image;
    if (ownsImage) {
      _ownedImages.add(image);
    } else {
      _ownedImages.remove(image);
    }
  }

  Future<void> setImageWithUrl(String url, String forKey) async {
    final image = await decodeImageFromList(
      (await get(Uri.parse(url))).bodyBytes,
    );
    _replaceImage(image, forKey, ownsImage: true);
  }

  void setText(TextPainter textPainter, String forKey) {
    if (textPainter.textDirection == null) {
      textPainter.textDirection = TextDirection.ltr;
      textPainter.layout();
    }
    dynamicText[forKey] = textPainter;
  }

  void setDynamicDrawer(SVGACustomDrawer drawer, String forKey) {
    dynamicDrawer[forKey] = drawer;
  }

  void reset() {
    for (final image in _ownedImages) {
      image.dispose();
    }
    _ownedImages.clear();
    dynamicHidden.clear();
    dynamicImages.clear();
    dynamicText.clear();
    dynamicDrawer.clear();
  }
}
