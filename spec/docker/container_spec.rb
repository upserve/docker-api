require 'spec_helper'

# WARNING if you're re-recording any of these VCRs, you must be running the
# Docker daemon and have the base Image pulled.
describe Docker::Container do
  subject { described_class.send(:new, :id => rand(10000).to_s) }

  describe '#to_s' do
    let(:id) { 'bf119e2' }
    let(:connection) { Docker::Connection.new }
    let(:expected_string) {
      "Docker::Container { :id => #{id}, :connection => #{connection} }"
    }
    before do
      {
        :@id => id,
        :@connection => connection
      }.each { |k, v| subject.instance_variable_set(k, v) }
    end

    its(:to_s) { should == expected_string }
  end

  describe '#json' do
    context 'when the HTTP response status is not 200' do
      before { Excon.stub({ :method => :get }, { :status => 500 }) }
      after { Excon.stubs.shift }

      it 'raises an error' do
        expect { subject.json }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response status is 200' do
      subject { described_class.create('Cmd' => %w[true], 'Image' => 'base') }
      let(:description) { subject.json }

      it 'returns the description as a Hash', :vcr do
        description.should be_a(Hash)
        description['ID'].should start_with(subject.id)
      end
    end
  end

  describe '#changes' do
    context 'when the HTTP response status is not 200' do
      before { Excon.stub({ :method => :get }, { :status => 500 }) }
      after { Excon.stubs.shift }

      it 'raises an error' do
        expect { subject.changes }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response status is 200' do
      subject { described_class.create('Cmd' => %w[true], 'Image' => 'base') }
      let(:changes) { subject.changes }

      before { subject.tap(&:start).tap(&:wait) }

      it 'returns the changes as an array', :vcr do
        changes.should be_a Array
        changes.should be_all { |change| change.is_a?(Hash) }
        changes.length.should_not be_zero
      end
    end
  end

  describe '#export' do
    context 'when the HTTP response status is not 200' do
      before { Excon.stub({ :method => :get }, { :status => 500 }) }
      after { Excon.stubs.shift }

      it 'raises an error' do
        expect { subject.export { } }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response status is 200' do
      subject {
        Docker::Container.create('Cmd' => %w[rm -rf / --no-preserve-root],
                                 'Image' => 'base')
      }
      before { subject.start }

      it 'yields each chunk', :vcr do
        first = nil
        subject.export do |chunk|
          first = chunk
          break
        end
        first[257..261].should == "ustar" # Make sure the export is a tar.
      end
    end
  end

  describe '#attach' do
    context 'when the HTTP response status is not 200' do
      before { Excon.stub({ :method => :post }, { :status => 500 }) }
      after { Excon.stubs.shift }

      it 'raises an error' do
        expect { subject.attach { } }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response status is 200' do
      subject { described_class.create('Cmd' => %w[uname -r],
                                       'Image' => 'base') }

      it 'yields each chunk', :vcr do
        subject.tap(&:start).attach { |chunk|
          chunk.should == "3.8.0-25-generic\n"
        }
      end
    end
  end

  describe '#start' do
    context 'when the HTTP response status is not 200' do
      before { Excon.stub({ :method => :post }, { :status => 500 }) }
      after { Excon.stubs.shift }

      it 'raises an error' do
        expect { subject.start }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response status is 200' do
      subject {
        described_class.create('Cmd' => %w[true], 'Image' => 'base')
      }

      it 'starts the container', :vcr do
        subject.start
        described_class.all.map(&:id).should be_any { |id|
          id.start_with?(subject.id)
        }
      end
    end
  end

  describe '#stop' do
    context 'when the HTTP response status is not 204' do
      before { Excon.stub({ :method => :post }, { :status => 500 }) }
      after { Excon.stubs.shift }

      it 'raises an error' do
        expect { subject.stop }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response status is 204' do
      subject { described_class.create('Cmd' => %w[ls], 'Image' => 'base') }

      it 'stops the container', :vcr do
        subject.tap(&:start).stop
        described_class.all(:all => true).map(&:id).should be_any { |id|
          id.start_with?(subject.id)
        }
        described_class.all.map(&:id).should be_none { |id|
          id.start_with?(subject.id)
        }
      end
    end
  end

  describe '#kill' do
    context 'when the HTTP response status is not 204' do
      before { Excon.stub({ :method => :post }, { :status => 500 }) }
      after { Excon.stubs.shift }

      it 'raises an error' do
        expect { subject.kill }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response status is 204' do
      subject { described_class.create('Cmd' => ['ls'], 'Image' => 'base') }

      it 'kills the container', :vcr do
        subject.kill
        described_class.all.map(&:id).should be_none { |id|
          id.start_with?(subject.id)
        }
        described_class.all(:all => true).map(&:id).should be_any { |id|
          id.start_with?(subject.id)
        }
      end
    end
  end

  describe '#restart' do
    context 'when the HTTP response status is not 204' do
      before { Excon.stub({ :method => :post }, { :status => 500 }) }
      after { Excon.stubs.shift }

      it 'raises an error' do
        expect { subject.restart }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response status is 204' do
      subject {
        described_class.create('Cmd' => %w[/usr/bin/sleep 50],
                               'Image' => 'base')
      }

      it 'restarts the container', :vcr do
        subject.start
        described_class.all.map(&:id).should be_any { |id|
          id.start_with?(subject.id)
        }
        subject.stop
        described_class.all.map(&:id).should be_none { |id|
          id.start_with?(subject.id)
        }
        subject.restart
        described_class.all.map(&:id).should be_any { |id|
          id.start_with?(subject.id)
        }
      end
    end
  end

  describe '#wait' do
    context 'when the HTTP response status is not 200' do
      before { Excon.stub({ :method => :post }, { :status => 500 }) }
      after { Excon.stubs.shift }

      it 'raises an error' do
        expect { subject.wait }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response status is 200' do
      subject {
        described_class.create('Cmd' => %w[tar nonsense],
                               'Image' => 'base') }

      it 'waits for the command to finish', :vcr do
        subject.start
        subject.wait['StatusCode'].should == 64
      end
    end
  end

  describe '#commit' do
    context 'when the HTTP response status is not 200' do
      before { Excon.stub({ :method => :post }, { :status => 500 }) }
      after { Excon.stubs.shift }

      it 'raises an error' do
        expect { subject.commit }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response status is 200' do
      let(:image) { subject.commit }
      subject { described_class.create('Cmd' => %w[ls], 'Image' => 'base') }

      before { subject.start }

      it 'creates a new Image from the  Container\'s changes', :vcr do
        image.should be_a Docker::Image
        image.id.should_not be_nil
      end
    end
  end

  describe '.create' do
    subject { described_class }

    context 'when the body is not a Hash' do
      it 'raises an error' do
        expect { subject.create(:not_a_hash) }
            .to raise_error(Docker::Error::ArgumentError)
      end
    end

    context 'when the Container does not yet exist and the body is a Hash' do
      context 'when the HTTP request does not return a 200' do
        before { Excon.stub({ :method => :post }, { :status => 400 }) }
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.create }.to raise_error(Docker::Error::ClientError)
        end
      end

      context 'when the HTTP request returns a 200' do
        let(:options) do
          {
            "Hostname"     => "",
            "User"         => "",
            "Memory"       => 0,
            "MemorySwap"   => 0,
            "AttachStdin"  => false,
            "AttachStdout" => false,
            "AttachStderr" => false,
            "PortSpecs"    => nil,
            "Tty"          => false,
            "OpenStdin"    => false,
            "StdinOnce"    => false,
            "Env"          => nil,
            "Cmd"          => ["date"],
            "Dns"          => nil,
            "Image"        => "base",
            "Volumes"      => {},
            "VolumesFrom"  => ""
          }
        end
        let(:container) { subject.create(options) }

        it 'sets the id', :vcr do
          container.should be_a Docker::Container
          container.id.should_not be_nil
          container.connection.should_not be_nil
        end
      end
    end
  end

  describe '.all' do
    subject { described_class }

    context 'when the HTTP response is not a 200' do
      before { Excon.stub({ :method => :get }, { :status => 500 }) }
      after { Excon.stubs.shift }

      it 'raises an error' do
        expect { subject.all }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response is a 200' do
      before { described_class.create('Cmd' => ['ls'], 'Image' => 'base') }

      it 'materializes each Container into a Docker::Container', :vcr do
        subject.all(:all => true).should be_all { |container|
          container.is_a?(Docker::Container)
        }
        subject.all(:all => true).length.should_not be_zero
      end
    end
  end
end
