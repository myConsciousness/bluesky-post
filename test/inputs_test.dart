// Copyright 2026 Shinya Kato. All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided the conditions.

import 'package:bluesky_post/src/inputs.dart';
import 'package:test/test.dart';

void main() {
  group('parseCsv', () {
    test('splits and trims each element', () {
      expect(parseCsv('a,b,c'), ['a', 'b', 'c']);
      expect(parseCsv('a, b ,  c'), ['a', 'b', 'c']);
    });

    test('drops empty elements', () {
      expect(parseCsv('a,,b, ,c'), ['a', 'b', 'c']);
      expect(parseCsv('a,b,'), ['a', 'b']);
      expect(parseCsv(',a'), ['a']);
    });

    test('returns empty list for empty or whitespace input', () {
      expect(parseCsv(''), isEmpty);
      expect(parseCsv('   '), isEmpty);
      expect(parseCsv(',,,'), isEmpty);
    });

    test('keeps a single element', () {
      expect(parseCsv('  solo  '), ['solo']);
    });
  });

  group('parseCsvOrNull', () {
    test('returns null when empty', () {
      expect(parseCsvOrNull(''), isNull);
      expect(parseCsvOrNull('  , ,'), isNull);
    });

    test('returns list when non-empty', () {
      expect(parseCsvOrNull('en, ja'), ['en', 'ja']);
    });
  });

  group('parseCsvPositional', () {
    test('preserves empty elements for index alignment', () {
      expect(parseCsvPositional('a,,c'), ['a', '', 'c']);
      expect(parseCsvPositional('a, ,c'), ['a', '', 'c']);
    });

    test('trims each element', () {
      expect(parseCsvPositional(' a , b '), ['a', 'b']);
    });

    test('keeps a trailing empty', () {
      expect(parseCsvPositional('a,'), ['a', '']);
    });

    test('returns empty list for blank input', () {
      expect(parseCsvPositional(''), isEmpty);
      expect(parseCsvPositional('   '), isEmpty);
    });
  });

  group('resolveService', () {
    test('defaults to bsky.social when empty', () {
      expect(resolveService(''), 'bsky.social');
      expect(resolveService('   '), 'bsky.social');
    });

    test('trims and uses provided service', () {
      expect(resolveService('  example.com  '), 'example.com');
      expect(resolveService('bsky.social'), 'bsky.social');
    });
  });

  group('altAt', () {
    final alts = ['first', 'second'];

    test('returns aligned alt when in range', () {
      expect(altAt(alts, 0), 'first');
      expect(altAt(alts, 1), 'second');
    });

    test('returns empty string when out of range', () {
      expect(altAt(alts, 2), '');
      expect(altAt(alts, -1), '');
      expect(altAt(const [], 0), '');
    });
  });

  group('parseRetryCount', () {
    test('empty falls back to default with no warning', () {
      final result = parseRetryCount('');
      expect(result.value, 5);
      expect(result.warning, isNull);
    });

    test('respects a custom fallback', () {
      final result = parseRetryCount('', fallback: 3);
      expect(result.value, 3);
      expect(result.warning, isNull);
    });

    test('parses a valid integer with no warning', () {
      final result = parseRetryCount('10');
      expect(result.value, 10);
      expect(result.warning, isNull);
    });

    test('parses zero as valid', () {
      final result = parseRetryCount('0');
      expect(result.value, 0);
      expect(result.warning, isNull);
    });

    test('non-integer falls back with a warning', () {
      final result = parseRetryCount('abc');
      expect(result.value, 5);
      expect(result.warning, isNotNull);
      expect(result.warning, contains('abc'));
    });

    test('negative falls back with a warning', () {
      final result = parseRetryCount('-2');
      expect(result.value, 5);
      expect(result.warning, isNotNull);
    });
  });

  group('resolveEmbedKind', () {
    EmbedKind resolve({
      bool quote = false,
      bool images = false,
      bool video = false,
      bool link = false,
    }) =>
        resolveEmbedKind(
          hasQuote: quote,
          hasImages: images,
          hasVideo: video,
          hasLinkPreview: link,
        );

    test('quote with images -> recordWithMedia', () {
      expect(resolve(quote: true, images: true), EmbedKind.recordWithMedia);
    });

    test('quote with video -> recordWithMedia', () {
      expect(resolve(quote: true, video: true), EmbedKind.recordWithMedia);
    });

    test('quote alone -> record', () {
      expect(resolve(quote: true), EmbedKind.record);
    });

    test('quote takes precedence over link preview', () {
      expect(resolve(quote: true, link: true), EmbedKind.record);
    });

    test('images without quote -> images', () {
      expect(resolve(images: true), EmbedKind.images);
    });

    test('images take precedence over video', () {
      expect(resolve(images: true, video: true), EmbedKind.images);
    });

    test('video without quote or images -> video', () {
      expect(resolve(video: true), EmbedKind.video);
    });

    test('media takes precedence over link preview', () {
      expect(resolve(images: true, link: true), EmbedKind.images);
      expect(resolve(video: true, link: true), EmbedKind.video);
    });

    test('link preview only -> external', () {
      expect(resolve(link: true), EmbedKind.external);
    });

    test('nothing -> none', () {
      expect(resolve(), EmbedKind.none);
    });
  });
}
