// Copyright 2026 Shinya Kato. All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided the conditions.

/// Pure input-parsing helpers for the Bluesky post action.
///
/// Everything in this file is intentionally free of network access and of the
/// `bluesky` SDK types so that it can be unit tested without credentials.

/// The maximum number of images a single Bluesky post can embed.
const int maxImages = 4;

/// The kind of embed to attach to a post.
///
/// The `app.bsky.feed.post` embed is a union, so exactly one kind can be
/// attached. [resolveEmbedKind] encodes the priority between them.
enum EmbedKind {
  recordWithMedia,
  record,
  images,
  video,
  external,
  none,
}

/// The result of parsing the `retry-count` input.
class RetryCount {
  const RetryCount(this.value, {this.warning});

  /// The resolved retry count.
  final int value;

  /// A human readable warning when the raw input was invalid and [value]
  /// fell back to the default. `null` when the input was valid or empty.
  final String? warning;

  @override
  bool operator ==(Object other) =>
      other is RetryCount && other.value == value && other.warning == warning;

  @override
  int get hashCode => Object.hash(value, warning);

  @override
  String toString() => 'RetryCount(value: $value, warning: $warning)';
}

/// Splits a CSV [raw] string into trimmed, non-empty elements.
///
/// Each element is individually trimmed and empty elements are dropped, so
/// `"a, ,b ,"` becomes `['a', 'b']`.
List<String> parseCsv(final String raw) => raw
    .split(',')
    .map((final e) => e.trim())
    .where((final e) => e.isNotEmpty)
    .toList();

/// Like [parseCsv] but returns `null` when the result would be empty.
///
/// Useful for optional API parameters that must be omitted (not sent as an
/// empty list) when unset.
List<String>? parseCsvOrNull(final String raw) {
  final values = parseCsv(raw);
  return values.isEmpty ? null : values;
}

/// Splits a CSV [raw] string into trimmed elements, preserving empties.
///
/// Unlike [parseCsv], empty elements are kept so positional alignment holds,
/// e.g. `"a, ,c"` becomes `['a', '', 'c']`. This is used for alt-text inputs
/// where the nth alt must line up with the nth media file. A completely empty
/// input yields an empty list rather than a single empty element.
List<String> parseCsvPositional(final String raw) {
  if (raw.trim().isEmpty) {
    return const [];
  }

  return raw.split(',').map((final e) => e.trim()).toList();
}

/// Resolves the ATP service authority, defaulting to `bsky.social`.
String resolveService(final String raw) {
  final service = raw.trim();
  return service.isEmpty ? 'bsky.social' : service;
}

/// Returns the alt text aligned to [index], or an empty string when there is
/// no corresponding entry.
String altAt(final List<String> alts, final int index) =>
    index >= 0 && index < alts.length ? alts[index] : '';

/// Parses the `retry-count` input, falling back to [fallback] (default 5).
///
/// - An empty input resolves to [fallback] with no warning (the documented
///   default behaviour).
/// - A non-integer or non-positive input resolves to [fallback] with a
///   warning describing the fallback.
RetryCount parseRetryCount(final String raw, {final int fallback = 5}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return RetryCount(fallback);
  }

  final parsed = int.tryParse(trimmed);
  if (parsed == null || parsed < 0) {
    return RetryCount(
      fallback,
      warning: 'Invalid retry-count "$raw"; falling back to $fallback.',
    );
  }

  return RetryCount(parsed);
}

/// Resolves which single embed kind to attach, following the documented
/// priority:
///
/// 1. quote + media  -> [EmbedKind.recordWithMedia]
/// 2. quote          -> [EmbedKind.record]
/// 3. images         -> [EmbedKind.images]
/// 4. video          -> [EmbedKind.video]
/// 5. link preview   -> [EmbedKind.external]
/// 6. otherwise      -> [EmbedKind.none]
EmbedKind resolveEmbedKind({
  required final bool hasQuote,
  required final bool hasImages,
  required final bool hasVideo,
  required final bool hasLinkPreview,
}) {
  final hasMedia = hasImages || hasVideo;

  if (hasQuote && hasMedia) return EmbedKind.recordWithMedia;
  if (hasQuote) return EmbedKind.record;
  if (hasImages) return EmbedKind.images;
  if (hasVideo) return EmbedKind.video;
  if (hasLinkPreview) return EmbedKind.external;

  return EmbedKind.none;
}
