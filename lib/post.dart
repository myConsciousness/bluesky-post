// Copyright 2026 Shinya Kato. All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided the conditions.

// 🎯 Dart imports:
import 'dart:async';

// 📦 Package imports:
import 'package:actions_toolkit_dart/core.dart' as core;
import 'package:atproto_core/atproto_core.dart' as xrpc;
import 'package:bluesky/app_bsky_feed_post.dart' as bsky;
import 'package:bluesky/app_bsky_richtext_facet.dart' as bsky;
import 'package:bluesky/atproto.dart' as atp;
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/com_atproto_label_defs.dart' as bsky;
import 'package:bluesky_text/bluesky_text.dart';

// 🌎 Project imports:
import 'src/embed.dart';
import 'src/inputs.dart';

const _linkConfig = LinkConfig(
  excludeProtocol: true,
  enableShortening: true,
);

/// Entry point for the action: create a Bluesky post from the workflow inputs.
///
/// Any failure is surfaced through [core.setFailed] so the action exits with a
/// non-zero status instead of silently succeeding.
Future<void> post() async {
  try {
    await _run();
  } catch (e) {
    core.setFailed(message: 'Failed to create the Bluesky post: $e');
  }
}

Future<void> _run() async {
  final service = resolveService(core.getInput(name: 'service'));

  final retry = parseRetryCount(core.getInput(name: 'retry-count'));
  if (retry.warning != null) {
    core.warning(message: retry.warning!);
  }
  final retryConfig = xrpc.RetryConfig(maxAttempts: retry.value);

  final bluesky = await _createClient(service, retryConfig);

  final text = BlueskyText(
    core.getInput(name: 'text', options: core.InputOptions(required: true)),
    linkConfig: _linkConfig,
  ).format();
  final facets = await text.entities.toFacets(service: service);

  final reply = await _resolveReply(bluesky);
  final embed = await _resolveEmbed(bluesky);

  final created = await bluesky.feed.post.create(
    text: text.value,
    facets: facets.map(bsky.RichtextFacet.fromJson).toList(),
    reply: reply,
    embed: embed,
    langs: parseCsvOrNull(core.getInput(name: 'langs')),
    labels: _labels,
    tags: parseCsvOrNull(core.getInput(name: 'tags')),
  );

  core.info(message: 'Sent a post successfully!');
  core.info(message: 'cid = [${created.data.cid}]');
  core.info(message: 'uri = [${created.data.uri}]');

  core.setOutput(name: 'uri', value: created.data.uri.toString());
  core.setOutput(name: 'cid', value: created.data.cid);
}

Future<bsky.Bluesky> _createClient(
  final String service,
  final xrpc.RetryConfig retryConfig,
) async {
  final session = await atp.createSession(
    service: service,
    identifier: core.getInput(
      name: 'identifier',
      options: core.InputOptions(required: true, trimWhitespace: true),
    ),
    password: core.getInput(
      name: 'password',
      options: core.InputOptions(required: true, trimWhitespace: true),
    ),
    retryConfig: retryConfig,
  );

  return bsky.Bluesky.fromSession(
    session.data,
    service: service,
    retryConfig: retryConfig,
  );
}

Future<bsky.ReplyRef?> _resolveReply(final bsky.Bluesky bluesky) async {
  final replyTo = core.getInput(
    name: 'reply-to',
    options: core.InputOptions(trimWhitespace: true),
  );

  if (replyTo.isEmpty) {
    return null;
  }

  return resolveReplyRef(bluesky, replyTo);
}

Future<bsky.UFeedPostEmbed?> _resolveEmbed(final bsky.Bluesky bluesky) async {
  return buildEmbed(
    bluesky,
    imagePaths: _imagePaths(),
    imageAlts: parseCsvPositional(
      core.getInput(name: 'media-alt', options: core.InputOptions()),
    ),
    videoPath: core.getInput(
      name: 'video',
      options: core.InputOptions(trimWhitespace: true),
    ),
    videoAlt: core.getInput(
      name: 'video-alt',
      options: core.InputOptions(trimWhitespace: true),
    ),
    linkPreviewUrl: core.getInput(
      name: 'link-preview-url',
      options: core.InputOptions(trimWhitespace: true),
    ),
    quoteUri: core.getInput(
      name: 'quote',
      options: core.InputOptions(trimWhitespace: true),
    ),
  );
}

/// Reads the image paths, capping at [maxImages] with a warning when exceeded.
List<String> _imagePaths() {
  final paths = parseCsv(core.getInput(name: 'media'));

  if (paths.length > maxImages) {
    core.warning(
      message: 'Bluesky supports at most $maxImages images; '
          'ignoring ${paths.length - maxImages} extra file(s).',
    );
    return paths.sublist(0, maxImages);
  }

  return paths;
}

bsky.UFeedPostLabels? get _labels {
  final labels = parseCsv(core.getInput(name: 'labels'));

  if (labels.isEmpty) {
    return null;
  }

  return bsky.UFeedPostLabels.selfLabels(
    data: bsky.SelfLabels(
      values: labels.map((final e) => bsky.SelfLabel(val: e)).toList(),
    ),
  );
}
