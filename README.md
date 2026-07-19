[![GitHub Sponsor](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=ff69b4)](https://github.com/sponsors/myConsciousness)
[![GitHub Sponsor](https://img.shields.io/static/v1?label=Maintainer&message=myConsciousness&logo=GitHub&color=00acee)](https://github.com/myConsciousness)

[![Powered by atproto](https://img.shields.io/badge/Powered%20by-atproto-00acee.svg)](https://github.com/myConsciousness/atproto.dart/tree/main/packages/atproto)
[![Powered by bluesky](https://img.shields.io/badge/Powered%20by-bluesky-00acee.svg)](https://github.com/myConsciousness/atproto.dart/tree/main/packages/bluesky)
[![Powered by bluesky_text](https://img.shields.io/badge/Powered%20by-bluesky_text-00acee.svg)](https://github.com/myConsciousness/atproto.dart/tree/main/packages/bluesky_text)

# Send a Post to Bluesky from GitHub Actions Workflow

Use this action to send a post from GitHub actions workflow.

This action is implemented in the Dart language and uses **[bluesky](https://github.com/myConsciousness/atproto.dart/tree/main/packages/bluesky)** for posting to Bluesky Social.

## Workflow Usage

Configure your workflow to use `myConsciousness/bluesky-post@v6`,
and provide the post you want to send as the `text` input.

> **Note** </br>
> `v6` is a major release. See the [Release Note](CHANGELOG.md) for the new
> `video`, `reply-to`, `quote`, multi-image `media`, and `uri`/`cid` output
> support, and for behaviour changes around media upload failures.

Provide Bluesky's ATP server with `identifier` (handle or email) and `password` to create a session.

For example:

```yml
name: Send Bluesky Post

on:
    [push]

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

Now whenever you push something to your repository, GitHub Actions
will post to Bluesky on your behalf.

> **Note** </br>
> In the Bluesky API, the `mention`, `link` and `tag` functions will not work unless
> the `facet` parameter is set correctly when the request is sent,
> but this Action will automatically extract valid handle and link
> from the text and set the facet.

## Specify Authority

Bluesky Social is a distributed microservice.
So you may possibly want to post to a ATP server other than `bsky.social`.

In that case, set the `service` parameter to the authority you wish to post as follows.
If the `service` parameter is omitted, the default is `bsky.social`.

```yml
name: Send Bluesky Post

on:
    [push]

jobs:
  post:
    runs-on: ubuntu-latest
    steps:
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
          service: "boobee.blue"
```

## Retry

Server error or network errors may temporarily occur during API communication to the ATP server.
In such cases, retrying at regular intervals may result in successful processing.

This Actions supports `Retry`, and you can specify the maximum number of retries.
The default retry count is 5.

You can specify the following.

```yml
name: Send Bluesky Post

on:
    [push]

jobs:
  post:
    runs-on: ubuntu-latest
    steps:
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
          retry-count: 5
```

## Attach Images

You can post text with up to **4 images** attached from specified file paths.
Pass the file paths to `media` in **_CSV format_**, and the corresponding alt
text to `media-alt` in **_CSV format_**. Each `media-alt` entry aligns by index
with `media`; leave an entry empty to skip alt text for that image.

```yml
name: Send Bluesky Post

on:
    [push]

jobs:
  post:
    runs-on: ubuntu-latest
    steps:
      # You must checkout resources
      - uses: actions/checkout@v3

      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          media: "cool_photo.png,another_photo.png"
          media-alt: "This is a cool photo!,And another one"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

> **Note** </br>
> If a media file is missing or fails to upload, the action fails instead of
> silently posting without the media.

## Attach a Video

You can attach a single video with the `video` parameter (and optional
`video-alt`). Video processing is asynchronous, so the action waits for the
upload job to finish before creating the post.

```yml
name: Send Bluesky Post

on:
    [push]

jobs:
  post:
    runs-on: ubuntu-latest
    steps:
      # You must checkout resources
      - uses: actions/checkout@v3

      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          video: cool_video.mp4
          video-alt: "This is a cool video!"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Reply to a Post

Set `reply-to` to the AT-URI of the post you want to reply to. The action
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

Set `quote` to the AT-URI of the post you want to quote. A quote can be combined
with `media` or `video` to attach media alongside the quoted post.

```yml
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Look at this!"
          quote: "at://did:plc:xxxx/app.bsky.feed.post/yyyy"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Attach Language Tags

You can give the post you are sending **BCP47 format language tags**.
One or more language tags can be set and passed to the `langs` parameter in **_CSV format_** as follows.

```yml
name: Send Bluesky Post

on:
    [push]

jobs:
  post:
    runs-on: ubuntu-latest
    steps:
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          langs: "en,ja"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Attach Self Labels

You can **label** any post you send.
You can set one or more labels, and pass the value of any label in the `labels` parameter in **_CSV format_** as follows.

```yml
name: Send Bluesky Post

on:
    [push]

jobs:
  post:
    runs-on: ubuntu-latest
    steps:
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          labels: "spam,porn"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Attach Tags

You can **tag** any post you send.
You can set one or more tags, and pass the value of any tag in the `tags` parameter in **_CSV format_** as follows.

```yml
name: Send Bluesky Post

on:
    [push]

jobs:
  post:
    runs-on: ubuntu-latest
    steps:
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          tags: "bluesky,awesome"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

> **Note** </br>
> The value specified in the `tags` parameter is different from hashtags in the text,
> which are generally displayed as metadata about the post in Bluesky's clients.

## Markdown Link

You can specify links in a generic markdown format.

```yml
name: Send Bluesky Post

on:
    [push]

jobs:
  post:
    runs-on: ubuntu-latest
    steps:
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "[This is a markdown link!](https://atprotodart.com)"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Attach Link Preview

You can attach link preview (link card) with `link-preview-url` parameter.

A post can hold only one embed, so when several embed inputs are supplied the
following priority applies:

1. `quote` + (`media` or `video`) — quoted post with media
2. `quote` — quoted post
3. `media` — images
4. `video` — video
5. `link-preview-url` — link card

If building the link preview fails, the action logs a warning and posts without
a preview card (a link card is decorative, so it does not fail the post).

```yml
name: Send Bluesky Post

on:
    [push]

jobs:
  post:
    runs-on: ubuntu-latest
    steps:
      - uses: myConsciousness/bluesky-post@v6
        with:
          text: "Hello, Bluesky!"
          link-preview-url: "https://atprotodart.com"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}
```

## Outputs

The action exposes the created post so later steps can reference it:

| Output | Description |
| ------ | ----------- |
| `uri`  | The AT-URI of the created post. |
| `cid`  | The CID of the created post. |

```yml
      - uses: myConsciousness/bluesky-post@v6
        id: post
        with:
          text: "Hello, Bluesky!"
          identifier: ${{ secrets.BLUESKY_IDENTIFIER }}
          password: ${{ secrets.BLUESKY_PASSWORD }}

      - run: echo "Posted ${{ steps.post.outputs.uri }} (${{ steps.post.outputs.cid }})"
```

## More Information

**bluesky_post** was designed and implemented by **_Shinya Kato ([@myConsciousness](https://github.com/myConsciousness))_**.

- [Creator Profile](https://github.com/myConsciousness)
- [License](https://github.com/myConsciousness/atproto.dart/blob/main/LICENSE)
- [Release Note](https://github.com/myConsciousness/atproto.dart/releases)
- [Bug Report](https://github.com/myConsciousness/atproto.dart/issues)
