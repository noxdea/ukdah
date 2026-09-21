# frozen_string_literal: true

RSpec.describe Ukdah do
  it "has a version number" do
    expect(Ukdah::VERSION).not_to be nil
  end

  it "parses folded and encoded headers" do
    message = described_class::Message.parse(
      "Subject: =?UTF-8?B?5pel5pys?=\n" \
      " X\nFrom: =?UTF-8?B?44GT44KT44Gr44Gh44Gv?= <a@example.test>\n\nbody"
    )
    expect(message.subject).to eq("日本 X")
    expect(message.from.first.name).to eq("こんにちは")
  end

  it "builds tolerant multipart trees and decodes attachments" do
    message = described_class::Message.parse(File.binread(File.join(__dir__, "fixtures", "multipart.eml")))
    expect(message.text_part).not_to be nil
    expect(message.html_part).not_to be nil
    expect(message.decoded(message.text_part)).to include("hello")
    expect(message.attachments.first.filename).to eq("テスト.txt")
    expect(message.attachments.first.body).to eq("abc")
    expect(message.inline_parts["image@example.test"]).not_to be nil
    expect(message.decoded(message.text_part, decoder: ->(bytes, charset) {
      "#{charset}:#{bytes}"
    })).to include("UTF-8:hello")
  end

  it "reads Japanese and malformed messages without raising" do
    japanese = described_class::Message.parse(File.binread(File.join(__dir__, "fixtures", "japanese.eml")))
    broken = described_class::Message.parse(File.binread(File.join(__dir__, "fixtures", "broken.eml")))
    expect(japanese.subject).to eq("日本語")
    expect(japanese.decoded(japanese.text_part)).to include("日本語")
    expect(broken.diagnostics).not_to be_empty
  end

  it "splits mbox envelopes without splitting a body From line" do
    messages = described_class::Mbox.each(File.open(File.join(__dir__, "fixtures", "messages.mbox"), "rb")).to_a
    expect(messages.map(&:subject)).to eq(["one", "two"])
    expect(messages.first.decoded(messages.first.text_part)).to include("From this is body")
  end

  it "groups quote segments and threads replies" do
    expect(Ukdah::Quote.segments("one\n> two\n> three\nfour")).to eq(
      [[0, ["one"]], [1, ["> two", "> three"]], [0, ["four"]]]
    )
    first = described_class::Message.parse("Message-ID: <a@example.test>\n\nfirst")
    reply = described_class::Message.parse("Message-ID: <b@example.test>\nIn-Reply-To: <a@example.test>\n\nreply")
    roots = Ukdah::Thread_.build([first, reply])
    expect(roots.length).to eq(1)
    expect(roots.first.children.map(&:message)).to eq([reply])
  end
end
