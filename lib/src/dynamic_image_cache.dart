import 'dart:ui' as ui;

/// Shares a dynamically decoded image only while one or more players use it.
///
/// [cacheKey] belongs to the caller: it should include the source and every
/// transformation that changes the decoded pixels (such as target size or
/// corner treatment). The cache retains no image after the final release.
class SvgaDynamicImageCache {
  SvgaDynamicImageCache._();

  static final _entries = <Object, _DynamicImageEntry>{};
  static final _pending = <Object, Future<_DynamicImageEntry?>>{};

  static Future<SvgaDynamicImageLease?> acquire(
    Object cacheKey, {
    required Future<ui.Image?> Function() loader,
  }) async {
    var entry = _entries[cacheKey];
    if (entry == null) {
      final pending = _pending.putIfAbsent(
        cacheKey,
        () => _load(cacheKey, loader),
      );
      entry = await pending;
      if (entry == null) return null;
    }
    entry.references++;
    return SvgaDynamicImageLease._(cacheKey, entry);
  }

  static Future<_DynamicImageEntry?> _load(
    Object cacheKey,
    Future<ui.Image?> Function() loader,
  ) async {
    try {
      final image = await loader();
      if (image == null) return null;
      final entry = _DynamicImageEntry(image);
      _entries[cacheKey] = entry;
      return entry;
    } finally {
      _pending.remove(cacheKey);
    }
  }

  static void _release(SvgaDynamicImageLease lease) {
    final entry = lease._entry;
    entry.references--;
    if (entry.references > 0) return;
    if (identical(_entries[lease._key], entry)) _entries.remove(lease._key);
    entry.image.dispose();
  }
}

class SvgaDynamicImageLease {
  SvgaDynamicImageLease._(this._key, this._entry);

  final Object _key;
  final _DynamicImageEntry _entry;
  bool _released = false;

  ui.Image get image => _entry.image;

  void release() {
    if (_released) return;
    _released = true;
    SvgaDynamicImageCache._release(this);
  }
}

class _DynamicImageEntry {
  _DynamicImageEntry(this.image);

  final ui.Image image;
  int references = 0;
}
