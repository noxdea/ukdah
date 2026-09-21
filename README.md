# Ukdah

Ukdah (ι Cancri, from Arabic *ʿuqdah*, “knot”) is a dependency-free Ruby
parser for RFC 5322 messages and MIME bodies. It is deliberately a parser,
not a mail transport client: it never connects to IMAP, POP, or SMTP.

## Features

- Folded headers, RFC 2047 encoded words, comments, quoted names, and groups
- RFC 2231 parameters, multipart trees, base64 and quoted-printable bodies
- Attachment and inline-part discovery, including `cid:` identifiers
- Tolerant parsing with diagnostics for malformed messages and boundaries
- mbox splitting with envelope and `Content-Length` support
- Lightweight `Message-ID`/`References` threading and quote segmentation
- Charset decoding through an injectable decoder; no runtime dependencies

## Installation

```ruby
gem "ukdah"
```

## Quick start

```ruby
require "ukdah"

message = Ukdah::Message.parse(File.binread("message.eml"))
puts message.subject
puts message.from.first.email
puts message.decoded(message.text_part)
message.attachments.each do |part|
  File.binwrite(part.filename, part.body)
end
```

Applications with a charset detector can inject it without adding a runtime
dependency:

```ruby
message.decoded(message.text_part, decoder: ->(bytes, charset) {
  Menkar.decode(bytes, Menkar.detect(bytes, hint: charset))
})
```

Malformed input is returned as far as it can be read. Inspect
`message.diagnostics` when a source needs attention. Ukdah does not sanitize
HTML; pass HTML parts through a sanitizer before displaying them.

## Development

```sh
bundle install
bundle exec rake
gem build --strict ukdah.gemspec
```

## License

MIT. See [LICENSE.txt](LICENSE.txt).
