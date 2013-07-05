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
      context 'as a hash' do
        let(:arg) { '{"yolo":"swag"}' }

        it 'parses the JSON into a Hash' do
          subject.should == { yolo: 'swag' }
        end
      end

      context 'as an array' do
        let(:arg) { '[{"yolo":"swag"}]' }

        it 'parses the JSON into a Hash' do
          subject.should == [{ yolo: 'swag' }]
        end
      end
    end
  end

  describe '.underscore' do
    subject { described_class.underscore(arg) }

    context 'when the argument is nil' do
      let(:arg) { nil }

      it { should be_nil }
    end

    context 'when the argument is empty' do
      let(:arg) { '' }

      it { should == arg }
    end

    context 'when the argument is already underscored' do
      let (:arg) { 'some_name' }

      it { should == arg }
    end

    context 'when the argument is camel-cased' do
      let (:arg) { 'SomeName' }

      it { should == 'some_name' }
    end

    context 'when the argument is lower camel-cased' do
      let (:arg) { 'someName' }

      it { should == 'some_name' }
    end

    context 'when the argument is a symbol' do
      let (:arg) { :someName }

      it { should == 'some_name' }
    end
  end

  describe '.transform_keys' do
    subject { described_class.transform_keys(arg) }

    context 'when the argument is nil' do
      let(:arg) { nil }

      it { should be_nil }
    end

    context 'when the argument is an empty string' do
      let(:arg) { '' }

      it { should == arg }
    end

    context 'when the argument is a string' do
      let(:arg) { 'some string' }

      it { should == arg }
    end

    context 'when the argument is an empty array' do
      let(:arg) { [] }

      it { should == arg }
    end

    context 'when the argument is an empty hash' do
      let(:arg) { {} }

      it { should == arg }
    end

    context 'with a hash' do
      let(:arg) { { a: 1, b: 12 } }

      it 'should call the block' do
        expect do |b|
          described_class.transform_keys(arg, &b)
        end.to yield_successive_args(:a, :b)
      end
    end

    context 'with an array of hashes' do
      let(:arg) { [{ a: 1 }, { b: 12 }] }

      it 'should call the block' do
        expect do |b|
          described_class.transform_keys(arg, &b)
        end.to yield_successive_args(:a, :b)
      end
    end
  end

  describe '.underscore_symbolize_keys' do
    subject { described_class.underscore_symbolize_keys(arg) }

    context 'when the argument is an empty hash' do
      let(:arg) { {} }

      it { should == arg }
    end

    context 'when the argument is a response hash' do
      let(:arg) {
        {
          Hostname:     "",
          User:         "",
          Memory:       0,
          MemorySwap:   0,
          AttachStdin:  false,
          AttachStdout: false,
          AttachStderr: false,
          PortSpecs:    nil,
          Tty:          false,
          OpenStdin:    false,
          StdinOnce:    false,
          Env:          nil,
          Cmd:          ["date"],
          Dns:          nil,
          Image:        "base",
          Volumes:      {},
          VolumesFrom:  ""
        }
      }

      it { should == {
        hostname:      "",
        user:          "",
        memory:        0,
        memory_swap:   0,
        attach_stdin:  false,
        attach_stdout: false,
        attach_stderr: false,
        port_specs:    nil,
        tty:           false,
        open_stdin:    false,
        stdin_once:    false,
        env:           nil,
        cmd:           ["date"],
        dns:           nil,
        image:         "base",
        volumes:       {},
        volumes_from:  ""
      } }
    end
  end

  describe '.camelize_keys' do
    let(:mode) { :lower }
    subject { described_class.camelize_keys(arg, mode) }

    context 'when the argument is an empty hash' do
      let(:arg) { {} }

      it { should == arg }
    end

    context 'when the argument is a request hash' do
      let(:mode) { :upper }
      let(:arg) {
        {
          hostname:      "",
          user:          "",
          memory:        0,
          memory_swap:   0,
          attach_stdin:  false,
          attach_stdout: false,
          attach_stderr: false,
          port_specs:    nil,
          tty:           false,
          open_stdin:    false,
          stdin_once:    false,
          env:           nil,
          cmd:           ["date"],
          dns:           nil,
          image:         "base",
          volumes:       {},
          volumes_from:  ""
        }
      }

      it { should == {
        Hostname:     "",
        User:         "",
        Memory:       0,
        MemorySwap:   0,
        AttachStdin:  false,
        AttachStdout: false,
        AttachStderr: false,
        PortSpecs:    nil,
        Tty:          false,
        OpenStdin:    false,
        StdinOnce:    false,
        Env:          nil,
        Cmd:          ["date"],
        Dns:          nil,
        Image:        "base",
        Volumes:      {},
        VolumesFrom:  ""
      } }
    end
  end

  describe '.camelize' do
    subject { described_class.camelize(arg, mode) }

    shared_context "general tests" do
      context 'when the argument is nil' do
        let(:arg) { nil }

        it { should be_nil }
      end

      context 'when the argument is an empty string' do
        let(:arg) { '' }

        it { should == '' }
      end
    end

    shared_context "default mode tests" do
      context 'when the arg is a a single word string' do
        let (:arg) { 'Cmd' }

        it { should == :Cmd }
      end

      context 'when the arg is a a single word symbol' do
        let (:arg) { :cmd }

        it { should == :Cmd }
      end

      context 'when the arg is a a multi word string' do
        let (:arg) { 'AttachStdin' }

        it { should == :AttachStdin }
      end

      context 'when the arg is a a multi word symbol' do
        let (:arg) { :attach_stdin }

        it { should == :AttachStdin }
      end
    end

    context 'in lower mode' do
      let(:mode) { :lower }

      include_context "general tests"

      context 'when the arg is a a single word string' do
        let (:arg) { 'Cmd' }

        it { should == :cmd }
      end

      context 'when the arg is a a single word symbol' do
        let (:arg) { :cmd }

        it { should == :cmd }
      end

      context 'when the arg is a a multi word string' do
        let (:arg) { 'AttachStdin' }

        it { should == :attachStdin }
      end

      context 'when the arg is a a multi word symbol' do
        let (:arg) { :attach_stdin }

        it { should == :attachStdin }
      end
    end

    context 'in upper mode' do
      let(:mode) { :upper }

      include_context "general tests"
      include_context "default mode tests"
    end

    context 'with no mode' do
      let(:mode) { nil }

      include_context "general tests"
      include_context "default mode tests"
    end
  end
end
