# Release Note

## v6.0.1

- Fixed the Docker build failure that made `v6` unusable. The base image is now `dart:3.12`; `bluesky` `2.x` and `bluesky_text` `1.x` require Dart SDK `>= 3.8.0`, which the previously pinned `dart:3.6` image could not satisfy. ([#4](https://github.com/myConsciousness/bluesky-post/issues/4))

## v6

- Upgraded to `bluesky` `2.1.x` (requires Dart SDK `>= 3.8.0`).
- Added `video` and `video-alt` inputs to attach a single video.
- `media` and `media-alt` now accept **CSV format** to attach up to 4 images.
- Added `reply-to` input to reply to a post by AT-URI (thread root resolved automatically).
- Added `quote` input to quote a post by AT-URI, combinable with media.
- Added `uri` and `cid` action **outputs** for the created post.
- Media and video upload failures now fail the action instead of silently posting without media.
- Link-preview failures are downgraded to a warning and the post continues without a preview card.

## v4

- Supported `langs` and `labels` as optional parameters. Pass them as CSV format. ([#668](https://github.com/myConsciousness/atproto.dart/issues/668))

## v3

- Fixed to automatically extract mentions and links contained in text and set facets appropriately. ([#384](https://github.com/myConsciousness/atproto.dart/issues/384))
- Support for uploading images from a specified file path. ([#384](https://github.com/myConsciousness/atproto.dart/issues/384))

## v2

- Allows the user to specify a specific authority to post to. ([#66](https://github.com/myConsciousness/atproto.dart/issues/66))
  - Use `service` parameter to specify authority. The default is `bsky.social`.
- The number of retries can now be specified. ([#126](https://github.com/myConsciousness/atproto.dart/issues/126))
- Fixed from `handle` to `identifier`.

## v1

- First release!

## v0

- Let's start.
