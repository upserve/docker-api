require 'spec_helper'

describe Docker::Util do
  subject { described_class }

  describe '.parse_json' do
    subject { described_class.parse_json(arg) }

    context 'when the argument is nil' do
      let(:arg) { nil }

      it { should be_nil }
    end

    context 'when the argument is empty' do
      let(:arg) { '' }

      it { should be_nil }
    end

    context 'when the argument is \'null\'' do
      let(:arg) { 'null' }

      it { should be_nil }
    end

    context 'when the argument is not valid JSON' do
      let(:arg) { '~~lol not valid json~~' }

      it 'raises an error' do
        expect { subject }.to raise_error Docker::Error::UnexpectedResponseError
      end
    end

    context 'when the argument is valid JSON' do
      let(:arg) { '{"yolo":"swag"}' }

      it 'parses the JSON into a Hash' do
        subject.should == { 'yolo' => 'swag' }
      end
    end
  end

  describe '.build_auth_header' do
    subject { described_class }

    let(:credentials) {
      {
        :username      => 'test',
        :password      => 'password',
        :email         => 'test@example.com',
        :serveraddress => 'https://registry.com/'
      }
    }
    let(:credential_string) { credentials.to_json }
    let(:x_registry_auth) { Base64.encode64(credential_string).gsub(/\n/, '') }
    let(:expected_headers) { { 'X-Registry-Auth' => x_registry_auth } }


    context 'given credentials as a Hash' do
      it 'returns an X-Registry-Auth header encoded' do
        expect(subject.build_auth_header(credentials)).to eq(expected_headers)
      end
    end

    context 'given credentials as a String' do
      it 'returns an X-Registry-Auth header encoded' do
        expect(
          subject.build_auth_header(credential_string)
        ).to eq(expected_headers)
      end
    end
  end

  describe '#decipher_messages' do
    context 'given both standard out and standard error' do
      let(:raw_text) {
        "\x01\x00\x00\x00\x00\x00\x00\x01a\x02\x00\x00\x00\x00\x00\x00\x01b"
      }
      let(:expected_messages) { [["a"], ["b"]] }

      it "returns a single message" do
        expect(
          Docker::Util.decipher_messages(raw_text)
        ).to eq(expected_messages)
      end
    end

    context 'given a single header' do
      let(:raw_text) { "\x01\x00\x00\x00\x00\x00\x00\x01a" }
      let(:expected_messages) { [["a"], []] }

      it "returns a single message" do
        expect(
          Docker::Util.decipher_messages(raw_text)
        ).to eq(expected_messages)
      end
    end

    context 'given two headers' do
      let(:raw_text) {
        "\x01\x00\x00\x00\x00\x00\x00\x01a\x01\x00\x00\x00\x00\x00\x00\x01b"
      }
      let(:expected_messages) { [["a", "b"], []] }

      it "returns both messages" do
        expect(
          Docker::Util.decipher_messages(raw_text)
        ).to eq(expected_messages)
      end
    end

    context 'given a header for text longer then 255 characters' do
      let(:raw_text) {
        "\x01\x00\x00\x00\x00\x00\x01\x01" + ("a" * 257)
      }
      let(:expected_messages) { [[("a" * 257)], []] }

      it "returns both messages" do
        expect(
          Docker::Util.decipher_messages(raw_text)
        ).to eq(expected_messages)
      end
    end
  end
end
