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

  describe '.camelize_keys!' do
    let(:hash) { { :hello_there => 'there', 'how' => 'are you' } }
    let(:expected) { { 'HelloThere' => 'there', 'how' => 'are you' } }

    before { subject.camelize_keys!(hash) }

    it 'camelizes each Symbolic key, but does not modify String keys' do
      hash.should == expected
    end
  end

  describe '.snakeify_keys!' do
    let(:hash) { { 'HelloThere' => 'there', :hOw => 'are you' } }
    let(:expected) { { :hello_there => 'there', :hOw => 'are you' } }

    before { subject.snakeify_keys!(hash) }

    it 'snakeifys each String key, but does not modify Symbolic keys' do
      hash.should == expected
    end
  end
end
