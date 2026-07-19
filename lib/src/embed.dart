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
import 'package:bluesky/app_bsky_embed_external.dart' as bsky;
import 'package:bluesky/app_bsky_embed_images.dart' as bsky;
import 'package:bluesky/app_bsky_embed_record.dart' as bsky;
import 'package:bluesky/app_bsky_embed_recordwithmedia.dart' as bsky;
import 'package:bluesky/app_bsky_embed_video.dart' as bsky;
import 'package:bluesky/app_bsky_feed_defs.dart' as bsky hide ReplyRef;
import 'package:bluesky/app_bsky_feed_post.dart' as bsky;
import 'package:bluesky/app_bsky_video_defs.dart' as bsky;
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/cardyb.dart' as cardyb;
import 'package:bluesky/com_atproto_repo_strongref.dart' as bsky;
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
Future<bsky.RepoStrongRef> resolveStrongRef(
  final bsky.Bluesky bluesky,
  final String uri,
) async {
  final post = await _findPost(bluesky, uri);
  return bsky.RepoStrongRef(uri: post.uri, cid: post.cid);
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
  final parentRef = bsky.RepoStrongRef(uri: parent.uri, cid: parent.cid);
  final root = _rootRefFromRecord(parent.record) ?? parentRef;

  return bsky.ReplyRef(root: root, parent: parentRef);
}

/// Extracts the thread root strong reference from a post record map, when the
/// post is itself a reply. Returns `null` for a top-level post.
bsky.RepoStrongRef? _rootRefFromRecord(final Map<String, dynamic> record) {
  final reply = record['reply'];
  if (reply is! Map) return null;

  final root = reply['root'];
  if (root is! Map) return null;

  final uri = root['uri'];
  final cid = root['cid'];
  if (uri is! String || cid is! String) return null;

  return bsky.RepoStrongRef(uri: xrpc.AtUri.parse(uri), cid: cid);
}

/// Builds the single embed to attach to the post, following the documented
/// priority in [resolveEmbedKind].
///
/// Media/quote failures propagate (fail loud). Only a link-preview failure is
/// downgraded to a warning, and the post continues without a preview.
Future<bsky.UFeedPostEmbed?> buildEmbed(
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
      return bsky.UFeedPostEmbed.embedImages(
        data: await _buildImages(bluesky, imagePaths, imageAlts),
      );

    case EmbedKind.video:
      return bsky.UFeedPostEmbed.embedVideo(
        data: await _buildVideo(bluesky, videoPath, videoAlt),
      );

    case EmbedKind.external:
      return _buildExternal(bluesky, linkPreviewUrl);

    case EmbedKind.record:
      return bsky.UFeedPostEmbed.embedRecord(
        data: bsky.EmbedRecord(
          record: await resolveStrongRef(bluesky, quoteUri),
        ),
      );

    case EmbedKind.recordWithMedia:
      return bsky.UFeedPostEmbed.embedRecordWithMedia(
        data: bsky.EmbedRecordWithMedia(
          record: bsky.EmbedRecord(
            record: await resolveStrongRef(bluesky, quoteUri),
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
Future<bsky.UEmbedRecordWithMediaMedia> _buildMedia(
  final bsky.Bluesky bluesky, {
  required final List<String> imagePaths,
  required final List<String> imageAlts,
  required final String videoPath,
  required final String videoAlt,
}) async {
  if (imagePaths.isNotEmpty) {
    return bsky.UEmbedRecordWithMediaMedia.embedImages(
      data: await _buildImages(bluesky, imagePaths, imageAlts),
    );
  }

  return bsky.UEmbedRecordWithMediaMedia.embedVideo(
    data: await _buildVideo(bluesky, videoPath, videoAlt),
  );
}

Future<bsky.EmbedImages> _buildImages(
  final bsky.Bluesky bluesky,
  final List<String> paths,
  final List<String> alts,
) async {
  final images = <bsky.EmbedImagesImage>[];

  for (var i = 0; i < paths.length; i++) {
    final blob = await _uploadBlob(bluesky, paths[i], label: 'image');
    images.add(bsky.EmbedImagesImage(image: blob, alt: altAt(alts, i)));
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

Future<bsky.UFeedPostEmbed?> _buildExternal(
  final bsky.Bluesky bluesky,
  final String url,
) async {
  try {
    final preview = await cardyb.getLinkPreview(Uri.parse(url));
    final thumbnail = await _uploadLinkPreviewThumbnail(
      bluesky,
      preview.data.image ?? '',
    );

    return bsky.UFeedPostEmbed.embedExternal(
      data: bsky.EmbedExternal(
        external: bsky.EmbedExternalExternal(
          uri: preview.data.url ?? url,
          title: preview.data.title ?? '',
          description: preview.data.description ?? '',
          thumb: thumbnail,
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
  final uploaded = await bluesky.atproto.repo.uploadBlob(bytes: bytes);

  return uploaded.data.blob;
}

/// Uploads a video and waits for the asynchronous processing job to finish.
Future<xrpc.Blob> _uploadVideo(
  final bsky.Bluesky bluesky,
  final String path,
) async {
  final bytes = await _readFile(path, label: 'video');

  final job = await bluesky.video.uploadVideo(bytes: bytes);
  var status = job.data;
  if (status.blob != null) {
    return status.blob!;
  }

  final deadline = DateTime.now().add(_videoJobTimeout);
  while (status.blob == null) {
    if (status.error != null ||
        status.state.knownValue == bsky.KnownJobStatusState.jOB_STATE_FAILED) {
      throw StateError(
        'Video processing failed: '
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

  final uploaded =
      await bluesky.atproto.repo.uploadBlob(bytes: image.bodyBytes);

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

Future<bsky.PostView> _findPost(
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
