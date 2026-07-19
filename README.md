[![GitHub Sponsor](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=ff69b4)](https://github.com/sponsors/myConsciousness)
[![GitHub Sponsor](https://img.shields.io/static/v1?label=Maintainer&message=myConsciousness&logo=GitHub&color=00acee)](https://github.com/myConsciousness)

[![Powered by atproto](https://img.shields.io/badge/Powered%20by-atproto-00acee.svg)](https://github.com/myConsciousness/atproto.dart/tree/main/packages/atproto)
[![Powered by bluesky](https://img.shields.io/badge/Powered%20by-bluesky-00acee.svg)](https://github.com/myConsciousness/atproto.dart/tree/main/packages/bluesky)
[![Powered by bluesky_text](https://img.shields.io/badge/Powered%20by-bluesky_text-00acee.svg)](https://github.com/myConsciousness/atproto.dart/tree/main/packages/bluesky_text)

# Send a Post to Bluesky from a GitHub Actions Workflow

Post to [Bluesky Social](https://bsky.app) directly from a GitHub Actions
workflow. Attach images or a video, reply to or quote a post, add language
tags, self labels, and tags, and read back the created post's `uri` and `cid`.

This action is written in Dart and powered by
**[bluesky](https://github.com/myConsciousness/atproto.dart/tree/main/packages/bluesky)**.

## Quick Start

Provide the post body as `text`, and authenticate against the ATP server with
`identifier` (handle or email) and `password`. Store the credentials as
[encrypted secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
rather than inlining them.

```yml
name: Send Bluesky Post

on: [push]

jobs:
  post:
    runs-on: ubuntu-latest
    steps:
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

Every example below shows only the `- uses:` step; drop it into the `steps:`
block of a workflow like the one above.

> **App passwords** </br>
> Use an [app password](https://bsky.app/settings/app-passwords) rather than
> your account password.

> **Facets are automatic** </br>
> Mentions, links, and tags in the text only render correctly when the request
> sets the `facet` parameter. This action extracts valid handles and links from
> the text and sets the facets for you.

## Inputs

| Input | Required | Description |
| ----- | :------: | ----------- |
| `text` | ✅ | The text body of the post. |
| `identifier` | ✅ | Handle or email used to log in (e.g. `shinyakato.bsky.social`). |
| `password` | ✅ | Password used to log in. An app password is recommended. |
| `media` | | Image file paths in CSV format. Up to 4 images. |
| `media-alt` | | Alt text for the images in CSV format, aligned by index with `media`. |
| `video` | | File path of a single video to attach. |
| `video-alt` | | Alt text for the video. |
| `reply-to` | | AT-URI of the post to reply to. |
| `quote` | | AT-URI of the post to quote. |
| `link-preview-url` | | URL to render as a link preview (link card). |
| `langs` | | BCP47 language tags in CSV format. |
| `labels` | | Self labels in CSV format. |
| `tags` | | Tags in CSV format. |
| `service` | | ATP server authority to post to. Defaults to `bsky.social`. |
| `retry-count` | | Maximum retries on server or network errors. Defaults to `5`. |

## Outputs

The action exposes the created post so later steps can reference it.

| Output | Description |
| ------ | ----------- |
| `uri` | The AT-URI of the created post. |
| `cid` | The CID of the created post. |

```yml
      - uses: myConsciousness/bluesky-post@v6
        id: post
        with:
          text: "Hello, Bluesky!"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}

      - run: echo "Posted ${{ steps.post.outputs.uri }} (${{ steps.post.outputs.cid }})"
```

## Attach Images

Attach up to **4 images** from local file paths. Pass the paths to `media` and
the alt text to `media-alt`, both in CSV format. Each `media-alt` entry aligns
by index with `media`; leave an entry empty to skip alt text for that image.

```yml
      # Checkout first so the image files exist in the workspace.
      - uses: actions/checkout@v4

      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          media: "cool_photo.png,another_photo.png"
          media-alt: "This is a cool photo!,And another one"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

> **Note** </br>
> If a media file is missing or fails to upload, the action fails rather than
> silently posting without the media.

## Attach a Video

Attach a single video with `video` (and optional `video-alt`). Video processing
is asynchronous, so the action waits for the upload job to finish before
creating the post.

```yml
      - uses: actions/checkout@v4

      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          video: cool_video.mp4
          video-alt: "This is a cool video!"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Reply to a Post

Set `reply-to` to the AT-URI of the post you are replying to. The action
resolves the thread root automatically.

```yml
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Nice post!"
          reply-to: "at://did:plc:xxxx/app.bsky.feed.post/yyyy"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Quote a Post

Set `quote` to the AT-URI of the post you are quoting. A quote can be combined
with `media` or `video` to attach media alongside the quoted post.

```yml
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Look at this!"
          quote: "at://did:plc:xxxx/app.bsky.feed.post/yyyy"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Attach a Link Preview

Attach a link preview (link card) with `link-preview-url`.

```yml
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          link-preview-url: "https://atprotodart.com"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

If the preview cannot be built, the action logs a warning and posts without a
card — a link preview is decorative, so it never fails the post.

### Embed priority

A post can hold only one embed. When several embed inputs are supplied, the
following priority applies:

1. `quote` + (`media` or `video`) — quoted post with media
2. `quote` — quoted post
3. `media` — images
4. `video` — video
5. `link-preview-url` — link card

## Markdown Links

Write links in standard Markdown syntax; the action converts them to facets.

```yml
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "[This is a markdown link!](https://atprotodart.com)"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Language Tags

Tag the post with one or more **BCP47** language tags, passed to `langs` in CSV
format.

```yml
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          langs: "en,ja"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Self Labels

Apply one or more self labels, passed to `labels` in CSV format.

```yml
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          labels: "sexual,nudity"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Tags

Apply one or more tags, passed to `tags` in CSV format.

```yml
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          tags: "bluesky,awesome"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

> **Note** </br>
> Tags passed via the `tags` parameter differ from hashtags written inline in
> the text. They are attached as metadata about the post.

## Post to a Different Authority

Bluesky is a distributed network, so you may want to post to an ATP server other
than `bsky.social`. Set `service` to the target authority. When omitted, it
defaults to `bsky.social`.

```yml
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          service: "boobee.blue"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Retry

Transient server or network errors can occur while talking to the ATP server,
and retrying after a short interval often succeeds. Set `retry-count` to the
maximum number of retries (default `5`).

```yml
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          retry-count: 5
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Versioning

`v6` is a major release that adds `video`, `reply-to`, `quote`, multi-image
`media`, and the `uri`/`cid` outputs, and makes media upload failures fail the
action instead of posting silently. See the [Release Note](CHANGELOG.md) for the
full list of changes.

## More Information

**bluesky_post** was designed and implemented by
**_Shinya Kato ([@myConsciousness](https://github.com/myConsciousness))_**.

- [Creator Profile](https://github.com/myConsciousness)
- [License](https://github.com/myConsciousness/atproto.dart/blob/main/LICENSE)
- [Release Note](https://github.com/myConsciousness/atproto.dart/releases)
- [Bug Report](https://github.com/myConsciousness/atproto.dart/issues)
