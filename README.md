<h1 align="center">Ukdah</h1>

<p align="center"><strong>Turn raw email and mbox files into readable MIME messages, without a mail client.</strong></p>

<p align="center">
  <a href="https://rubygems.org/gems/ukdah"><img src="https://img.shields.io/gem/v/ukdah" alt="Gem version"></a>
  <a href="https://github.com/noxdea/ukdah/actions/workflows/main.yml"><img src="https://github.com/noxdea/ukdah/actions/workflows/main.yml/badge.svg" alt="CI status"></a>
  <img src="https://img.shields.io/badge/Ruby-3.1%2B-cc342d" alt="Ruby 3.1 or newer">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#mailboxes-and-threads">Mailboxes and threads</a> ·
  <a href="#scope-and-safety">Scope and safety</a>
</p>

---

Ukdah is a dependency-free Ruby parser for RFC 5322 messages and MIME bodies.
It exposes headers, decoded text, attachments, diagnostics, and conversation
structure without connecting to IMAP, POP, or SMTP. The name comes from
ι Cancri and the Arabic *ʿuqdah*, “knot.”

## Features

- Folded headers, encoded words, address groups, and RFC 2231 parameters
- Multipart MIME trees with base64 and quoted-printable transfer decoding
- Attachment and inline-part discovery, including `cid:` identifiers
- Tolerant parsing with diagnostics for damaged messages
- mbox splitting, Message-ID threading, and quote segmentation
- Injectable charset decoder; no runtime dependencies

## Installation

Add `gem "ukdah"` to your Gemfile and run `bundle install`, or install directly:

```sh
gem install ukdah
```

Requires Ruby 3.1 or newer.

## Quick start

```ruby
require "ukdah"

raw = "From: Ada <ada@example.com>\r\n" \
      "Subject: Hello\r\n" \
      "Content-Type: text/plain; charset=UTF-8\r\n\r\n" \
      "A short note."

message = Ukdah::Message.parse(raw)
puts message.from.first.email           # => ada@example.com
puts message.subject                    # => Hello
puts message.decoded(message.text_part) # => A short note.
puts message.diagnostics
```

`message.attachments` returns MIME parts with decoded transfer bodies.
Treat their filenames as untrusted input; choose a safe destination name
before writing one to disk.

## Mailboxes and threads

```ruby
messages = Ukdah::Mbox.each(File.binread("archive.mbox")).to_a
threads = Ukdah::Thread_.build(messages)
```

`Mbox.each` accepts bytes or an IO object and yields parsed messages.
`Thread_.build` groups messages using Message-ID, References, and In-Reply-To.

## Charset decoding

Pass a decoder when the application has its own charset strategy:

```ruby
text = message.decoded(message.text_part, decoder: ->(bytes, charset) {
  bytes.force_encoding(charset || "UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
})
```

Without a custom decoder, Ukdah uses Ruby's `Encoding` support.

## Scope and safety

Ukdah parses messages only; it does not fetch, send, or sanitize HTML mail.
Sanitize `message.html_part` before display. For design rationale, see
[parsing-only scope](docs/adr/001-parsing-only.md) and
[decoder injection](docs/adr/002-decoder-injection.md).

## Development

```sh
bundle install
bundle exec rake
gem build --strict ukdah.gemspec
```

## License

[MIT](LICENSE.txt)
