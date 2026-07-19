// Copyright 2026 Shinya Kato. All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided the conditions.

// 🎯 Dart imports:
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

// 📦 Package imports:
import 'package:actions_toolkit_dart/core.dart' as actions;
import 'package:atproto_core/atproto_core.dart' as xrpc;
import 'package:bluesky/app_bsky_embed_video.dart' as bsky;
import 'package:bluesky/atproto.dart' as atp;
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/cardyb.dart' as cardyb;
import 'package:http/http.dart' as http;

// 🌎 Project imports:
import 'inputs.dart';

/// How long to wait for the asynchronous video processing job to finish.
const _videoJobTimeout = Duration(minutes: 5);

/// How long to wait between video job status polls.
const _videoPollInterval = Duration(seconds: 3);

/// Resolves a strong reference (uri + cid) for the post at [uri].
///
/// Throws a [FormatException] when the post cannot be found so the action
/// fails loudly instead of silently dropping the quote/reply.
Future<atp.StrongRef> resolveStrongRef(
  final bsky.Bluesky bluesky,
  final String uri,
) async {
  final post = await _findPost(bluesky, uri);
  return atp.StrongRef(cid: post.cid, uri: post.uri);
}

/// Resolves the [bsky.ReplyRef] for a reply to the post at [uri].
///
/// The parent is the target post. The root is the target's own thread root
/// when the target is itself a reply, otherwise the target post.
Future<bsky.ReplyRef> resolveReplyRef(
  final bsky.Bluesky bluesky,
  final String uri,
) async {
  final parent = await _findPost(bluesky, uri);
  final parentRef = atp.StrongRef(cid: parent.cid, uri: parent.uri);
  final root = parent.record.reply?.root ?? parentRef;

  return bsky.ReplyRef(root: root, parent: parentRef);
}

/// Builds the single embed to attach to the post, following the documented
/// priority in [resolveEmbedKind].
///
/// Media/quote failures propagate (fail loud). Only a link-preview failure is
/// downgraded to a warning, and the post continues without a preview.
Future<bsky.Embed?> buildEmbed(
  final bsky.Bluesky bluesky, {
  required final List<String> imagePaths,
  required final List<String> imageAlts,
  required final String videoPath,
  required final String videoAlt,
  required final String linkPreviewUrl,
  required final String quoteUri,
}) async {
  final kind = resolveEmbedKind(
    hasQuote: quoteUri.isNotEmpty,
    hasImages: imagePaths.isNotEmpty,
    hasVideo: videoPath.isNotEmpty,
    hasLinkPreview: linkPreviewUrl.isNotEmpty,
  );

  switch (kind) {
    case EmbedKind.none:
      return null;

    case EmbedKind.images:
      return bsky.Embed.images(
        data: await _buildImages(bluesky, imagePaths, imageAlts),
      );

    case EmbedKind.video:
      return bsky.Embed.video(
        data: await _buildVideo(bluesky, videoPath, videoAlt),
      );

    case EmbedKind.external:
      return _buildExternal(bluesky, linkPreviewUrl);

    case EmbedKind.record:
      return bsky.Embed.record(
        data: bsky.EmbedRecord(ref: await resolveStrongRef(bluesky, quoteUri)),
      );

    case EmbedKind.recordWithMedia:
      return bsky.Embed.recordWithMedia(
        data: bsky.EmbedRecordWithMedia(
          record: bsky.EmbedRecord(
            ref: await resolveStrongRef(bluesky, quoteUri),
          ),
          media: await _buildMedia(
            bluesky,
            imagePaths: imagePaths,
            imageAlts: imageAlts,
            videoPath: videoPath,
            videoAlt: videoAlt,
          ),
        ),
      );
  }
}

/// Builds the media half of a record-with-media embed, preferring images over
/// video to match the embed priority.
Future<bsky.EmbedMedia> _buildMedia(
  final bsky.Bluesky bluesky, {
  required final List<String> imagePaths,
  required final List<String> imageAlts,
  required final String videoPath,
  required final String videoAlt,
}) async {
  if (imagePaths.isNotEmpty) {
    return bsky.EmbedMedia.images(
      data: await _buildImages(bluesky, imagePaths, imageAlts),
    );
  }

  return bsky.EmbedMedia.video(
    data: await _buildVideo(bluesky, videoPath, videoAlt),
  );
}

Future<bsky.EmbedImages> _buildImages(
  final bsky.Bluesky bluesky,
  final List<String> paths,
  final List<String> alts,
) async {
  final images = <bsky.Image>[];

  for (var i = 0; i < paths.length; i++) {
    final blob = await _uploadBlob(bluesky, paths[i], label: 'image');
    images.add(bsky.Image(alt: altAt(alts, i), image: blob));
  }

  return bsky.EmbedImages(images: images);
}

Future<bsky.EmbedVideo> _buildVideo(
  final bsky.Bluesky bluesky,
  final String path,
  final String alt,
) async {
  final blob = await _uploadVideo(bluesky, path);

  return bsky.EmbedVideo(
    video: blob,
    alt: alt.isEmpty ? null : alt,
  );
}

Future<bsky.Embed?> _buildExternal(
  final bsky.Bluesky bluesky,
  final String url,
) async {
  try {
    final preview = await cardyb.findLinkPreview(Uri.parse(url));
    final thumbnail = await _uploadLinkPreviewThumbnail(
      bluesky,
      preview.data.image,
    );

    return bsky.Embed.external(
      data: bsky.EmbedExternal(
        external: bsky.EmbedExternalThumbnail(
          uri: preview.data.url,
          title: preview.data.title,
          description: preview.data.description,
          blob: thumbnail,
        ),
      ),
    );
  } catch (e) {
    actions.warning(
      message: 'Failed to build link preview for "$url"; '
          'posting without a preview card. ($e)',
    );
    return null;
  }
}

/// Reads and uploads a media file, failing loudly when it is missing.
Future<xrpc.Blob> _uploadBlob(
  final bsky.Bluesky bluesky,
  final String path, {
  required final String label,
}) async {
  final bytes = await _readFile(path, label: label);
  final uploaded = await bluesky.atproto.repo.uploadBlob(bytes);

  return uploaded.data.blob;
}

/// Uploads a video and waits for the asynchronous processing job to finish.
Future<xrpc.Blob> _uploadVideo(
  final bsky.Bluesky bluesky,
  final String path,
) async {
  final bytes = await _readFile(path, label: 'video');

  final job = await bluesky.video.uploadVideo(bytes);
  var status = job.data;
  if (status.blob != null) {
    return status.blob!;
  }

  final deadline = DateTime.now().add(_videoJobTimeout);
  while (status.blob == null) {
    if (status.error != null || status.state.toUpperCase().contains('FAILED')) {
      throw StateError(
        'Video processing failed (state: ${status.state}): '
        '${status.error ?? status.message ?? 'unknown error'}',
      );
    }

    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
        'Video processing did not finish within '
        '${_videoJobTimeout.inMinutes} minutes.',
      );
    }

    await Future<void>.delayed(_videoPollInterval);

    final polled = await bluesky.video.getJobStatus(jobId: status.jobId);
    status = polled.data.jobStatus;
  }

  return status.blob!;
}

Future<xrpc.Blob?> _uploadLinkPreviewThumbnail(
  final bsky.Bluesky bluesky,
  final String imageUrl,
) async {
  if (imageUrl.isEmpty) {
    return null;
  }

  final image = await http.get(Uri.parse(imageUrl));
  if (image.statusCode != 200) {
    return null;
  }

  final uploaded = await bluesky.atproto.repo.uploadBlob(image.bodyBytes);

  return uploaded.data.blob;
}

Future<Uint8List> _readFile(
  final String path, {
  required final String label,
}) async {
  final file = File(path);
  if (!file.existsSync()) {
    throw FileSystemException('The $label file was not found', path);
  }

  return file.readAsBytes();
}

Future<bsky.Post> _findPost(
  final bsky.Bluesky bluesky,
  final String uri,
) async {
  final parsed = xrpc.AtUri.parse(uri.trim());
  final response = await bluesky.feed.getPosts(uris: [parsed]);

  if (response.data.posts.isEmpty) {
    throw FormatException('No post was found for the AT-URI: $uri');
  }

  return response.data.posts.first;
}
