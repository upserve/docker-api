require 'spec_helper'

describe Docker::Exec do

  describe '#to_s' do
    subject {
      described_class.send(:new, Docker.connection, 'id' => rand(10000).to_s)
    }

    let(:id) { 'bf119e2' }
    let(:connection) { Docker.connection }
    let(:expected_string) {
      "Docker::Exec { :id => #{id}, :connection => #{connection} }"
    }
    before do
      {
        :@id => id,
        :@connection => connection
      }.each { |k, v| subject.instance_variable_set(k, v) }
    end

    its(:to_s) { should == expected_string }
  end

  describe '.create' do
    subject { described_class }

    context 'when the HTTP request returns a 201' do
      let(:container) {
        Docker::Container.create(
          'Cmd' => %w[sleep 5],
          'Image' => 'debian:wheezy'
        ).start!
      }
      let(:options) do
        {
          'AttachStdin' => false,
          'AttachStdout' => false,
          'AttachStderr' => false,
          'Tty' => false,
          'Cmd' => [
            'date'
          ],
          'Container' => container.id
        }
      end
      let(:process) { subject.create(options) }
      after { container.kill!.remove }

      it 'sets the id', :vcr do
        expect(process).to be_a Docker::Exec
        expect(process.id).to_not be_nil
        expect(process.connection).to_not be_nil
      end
    end

    context 'when the parent container does not exist' do
      before do
        Docker.options = { :mock => true }
        Excon.stub({ :method => :post }, { :status => 404 })
      end
      after do
        Excon.stubs.shift
        Docker.options = {}
      end

      it 'raises an error' do
        expect { subject.create }.to raise_error(Docker::Error::NotFoundError)
      end
    end
  end

  describe '#start!' do
    let(:container) {
      Docker::Container.create(
        'Cmd' => %w[sleep 10],
        'Image' => 'debian:wheezy'
      ).start!
    }

    context 'when the exec instance does not exist' do
      subject do
        described_class.send(:new, Docker.connection, 'id' => rand(10000).to_s)
      end

      it 'raises an error', :vcr do
        skip 'The Docker API returns a 200 (docker/docker#9341)'
        expect { subject.start! }.to raise_error(Docker::Error::NotFoundError)
      end
    end

    context 'when :detach is set to false' do
      subject {
        described_class.create(
          'Container' => container.id,
          'AttachStdout' => true,
          'Cmd' => ['bash','-c','sleep 2; echo hello']
        )
      }
      after { container.kill!.remove }

      it 'returns the stdout and stderr messages', :vcr do
        expect(subject.start!).to eq([["hello\n"],[]])
      end

      context 'block is passed' do
        it 'attaches to the stream', :vcr do
          chunk = nil
          subject.start! do |stream, c|
            chunk ||= c
          end
          expect(chunk).to eq("hello\n")
        end
      end
    end

    context 'when :detach is set to true' do
      subject {
        described_class.create('Container' => container.id, 'Cmd' => %w[date])
      }
      after { container.kill!.remove }

      it 'returns empty stdout and stderr messages', :vcr do
        expect(subject.start!(:detach => true)).to eq([[],[]])
      end
    end

    context 'when the command has already run' do
      subject {
        described_class.create('Container' => container.id, 'Cmd' => ['date'])
      }
      before { subject.start! }
      after { container.kill!.remove }

      it 'raises an error', :vcr do
        skip 'The Docker API returns a 200 (docker/docker#9341)'
        expect { subject.start! }.to raise_error(Docker::Error::NotFoundError)
      end
    end

    context 'when the HTTP request returns a 201' do
      subject {
        described_class.create('Container' => container.id, 'Cmd' => ['date'])
      }
      after { container.kill!.remove }

      it 'starts the exec instance', :vcr do
        expect { subject.start! }.not_to raise_error
      end
    end
  end

  describe '#resize' do
    let(:container) {
      Docker::Container.create(
        'Cmd' => %w[sleep 20],
        'Image' => 'debian:wheezy'
      ).start!
    }

    context 'when exec instance has TTY enabled' do
      let(:instance) do
        described_class.create(
          'Container' => container.id,
          'AttachStdin' => true,
          'Tty' => true,
          'Cmd' => %w[/bin/bash]
        )
      end
      after do
        container.kill!
        sleep 1
        container.remove
      end

      it 'returns a 200', :vcr do
        t = Thread.new do
          instance.start!(:tty => true)
        end
        sleep 1
        expect { instance.resize(:h => 10, :w => 30) }.not_to raise_error
        t.kill
      end
    end

    context 'when the exec instance does not exist' do
      subject do
        described_class.send(:new, Docker.connection, 'id' => rand(10000).to_s)
      end

      it 'raises an error', :vcr do
        skip 'The Docker API returns a 200 (docker/docker#9341)'
        expect { subject.resize }.to raise_error(Docker::Error::NotFoundError)
      end
    end
  end
end
