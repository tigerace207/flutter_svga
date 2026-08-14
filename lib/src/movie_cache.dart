import 'dart:async';
import 'dart:ui' as ui;

import 'proto/svga.pb.dart';

/// Chooses whether an SVGA keeps source texture dimensions or decodes them to
/// its rendered size. It does not change the animation timeline.
enum SvgaMovieFramePolicy { full, downsampleTextures }

/// Shares decoded, immutable SVGA template textures between players.
///
/// Each lease gets an independent movie and dynamic replacement entity. The
/// template's costly [ui.Image] textures and parsed vector paths are shared.
class SvgaMovieCache {
  SvgaMovieCache._();

  static const _maxEntries = 22;
  static const _maxDecodedBytes = 22 << 20;

  static final _entries = <String, _CachedMovieEntry>{};
  static final _pendingEntries = <String, Future<_CachedMovieEntry>>{};
  static int _decodedBytes = 0;
  static Future<void> _decodeTail = Future<void>.value();

  /// Maps nearby sizes to a shared texture bucket.
  static int quantizeDecodeDimension(int pixels) {
    const step = 64;
    return ((pixels.clamp(1, 2048) + step - 1) ~/ step) * step;
  }

  static Future<SvgaMovieLease> acquire(
    String cacheKey,
    Future<MovieEntity> Function() loader, {
    int priority = 1,
  }) async {
    var entry = _entries[cacheKey];
    if (entry == null) {
      final pending = _pendingEntries.putIfAbsent(
        cacheKey,
        () => _load(cacheKey, loader),
      );
      entry = await pending;
    }

    entry.references++;
    entry.priority = _normalizePriority(priority) > entry.priority
        ? _normalizePriority(priority)
        : entry.priority;
    entry.lastUsed = DateTime.now();
    _evictUnusedEntries();
    return SvgaMovieLease._(entry, _createPlayerMovie(entry.template));
  }

  static Future<_CachedMovieEntry> _load(
    String cacheKey,
    Future<MovieEntity> Function() loader,
  ) async {
    try {
      final template = await _decodeSerially(loader);
      template.autorelease = false;
      final entry = _CachedMovieEntry(template);
      _entries[cacheKey] = entry;
      _decodedBytes += entry.decodedBytes;
      return entry;
    } finally {
      _pendingEntries.remove(cacheKey);
    }
  }

  static Future<MovieEntity> _decodeSerially(
    Future<MovieEntity> Function() loader,
  ) async {
    final previous = _decodeTail;
    final completed = Completer<void>();
    _decodeTail = completed.future;
    await previous;
    try {
      return await loader();
    } finally {
      completed.complete();
    }
  }

  static MovieEntity _createPlayerMovie(MovieEntity template) {
    final movie = MovieEntity()..mergeFromMessage(template);
    movie
      ..autorelease = false
      ..bitmapCache = template.bitmapCache
      ..pathCache = template.pathCache
      ..audiosData = template.audiosData;
    return movie;
  }

  static void _release(SvgaMovieLease lease, Set<ui.Image> callerOwnedImages) {
    final images = Set<ui.Image>.identity()
      ..addAll(lease.movie.dynamicItem.dynamicImages.values);
    lease.movie.dynamicItem.reset();
    for (final image in images) {
      if (!callerOwnedImages.contains(image)) image.dispose();
    }
    final entry = lease._entry;
    entry.references--;
    entry.lastUsed = DateTime.now();
    _evictUnusedEntries();
  }

  static void _evictUnusedEntries() {
    while (_entries.length > _maxEntries || _decodedBytes > _maxDecodedBytes) {
      final candidates = _entries.entries
          .where((entry) => entry.value.references == 0)
          .toList();
      if (candidates.isEmpty) return;
      candidates.sort((a, b) {
        final priorityComparison = a.value.priority.compareTo(b.value.priority);
        return priorityComparison != 0
            ? priorityComparison
            : a.value.lastUsed.compareTo(b.value.lastUsed);
      });
      final oldest = candidates.first;
      _entries.remove(oldest.key);
      _decodedBytes -= oldest.value.decodedBytes;
      oldest.value.template.dispose();
    }
  }

  static int _normalizePriority(int priority) => priority.clamp(1, 4);
}

class SvgaMovieLease {
  SvgaMovieLease._(this._entry, this.movie);

  final _CachedMovieEntry _entry;
  final MovieEntity movie;
  bool _released = false;

  /// Releases the player movie. Supply images whose lifecycle is managed by
  /// the caller (for example [SvgaDynamicImageCache]) to avoid double dispose.
  void release({Set<ui.Image> callerOwnedImages = const <ui.Image>{}}) {
    if (_released) return;
    _released = true;
    SvgaMovieCache._release(this, callerOwnedImages);
  }
}

class _CachedMovieEntry {
  _CachedMovieEntry(this.template) : decodedBytes = _decodedBytesFor(template);

  final MovieEntity template;
  final int decodedBytes;
  int references = 0;
  int priority = 1;
  DateTime lastUsed = DateTime.now();

  static int _decodedBytesFor(MovieEntity movie) => movie.bitmapCache.values
      .fold(0, (total, image) => total + image.width * image.height * 4);
}
