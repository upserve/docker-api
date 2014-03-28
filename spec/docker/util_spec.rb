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

  describe '.fix_json' do
    let(:response) { '{"this":"is"}{"not":"json"}' }
    subject { Docker::Util.fix_json(response) }

    it 'fixes the "JSON" response that Docker returns' do
      subject.should == [
        {
          'this' => 'is'
        },
        {
          'not' => 'json'
        }
      ]
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
    let(:encoded_creds) { Base64.encode64(credential_string).gsub(/\n/, '') }
    let(:expected_headers) {
      {
        'X-Registry-Auth' => encoded_creds,
        'X-Registry-Config' => encoded_creds
      }
    }


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

  describe '.camelize_keys' do
    let(:input) {
      {
        :key_one => 'value1',
        :keyTwo => {
          :key_Three => 'value2'
        }
      }
    }

    context 'when there is no extra argument' do
      let(:expected) {
        {
          'KeyOne' => 'value1',
          'KeyTwo' => {
            'KeyThree' => 'value2'
          }
        }
      }

      it 'turns each key of a Hash into CamelCase' do
        expect(Docker::Util.camelize_keys(input)).to eq(expected)
      end
    end

    context 'when the extra argument is false' do
      let(:expected) {
        {
          'keyOne' => 'value1',
          'keyTwo' => {
            'keyThree' => 'value2'
          }
        }
      }

      it 'turns each key of a Hash into CamelCase' do
        expect(Docker::Util.camelize_keys(input, false)).to eq(expected)
      end
    end
  end

  describe '.camelize' do
    subject { strs.map { |str| Docker::Util.camelize(str) } }

    context 'when the String is already CamelCase' do
      let(:strs) { %w(CamelOne Cameltwo) }
      let(:expected) { strs }

      it 'does nothing' do
        expect(subject).to eq(expected)
      end
    end

    context 'when the String is snake_case' do
      let(:strs) { %w(snake_case1 snake2_case snake_3case) }
      let(:expected) { %w(SnakeCase1 Snake2Case Snake3case) }

      it 'converts it to CamelCase' do
        expect(subject).to eq(expected)
      end

      context 'when the second argument is false' do
        subject { strs.map { |str| Docker::Util.camelize(str, false) } }
        let(:expected) { %w(snakeCase1 snake2Case snake3case) }

        it 'converts it to camelCase' do
          expect(subject).to eq(expected)
        end
      end
    end
  end
end
