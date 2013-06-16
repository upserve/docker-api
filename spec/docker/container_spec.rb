require 'spec_helper'

# WARNING if you're re-recording any of these VCRs, you must be running the
# Docker daemon and have the base Image pulled.
describe Docker::Container, :class do
  describe '#initialize' do
    subject { described_class }

    context 'with no argument' do
      let(:container) { subject.new }

      it 'sets the id to nil' do
        container.id.should be_nil
      end

      it 'keeps the default Connection' do
        container.connection.should == Docker.connection
      end
    end

    context 'with an argument' do
      let(:id) { 'a7c2ee4' }
      let(:container) { subject.new(:id => id) }

      it 'sets the id to the argument' do
        container.id.should == id
      end

      it 'keeps the default Connection' do
        container.connection.should == Docker.connection
      end
    end

    context 'with two arguments' do
      context 'when the second argument is not a Docker::Connection' do
        let(:id) { 'abc123f' }
        let(:connection) { :not_a_connection }
        let(:container) { subject.new(:id => id, :connection => connection) }

        it 'raises an error' do
          expect { container }.to raise_error(Docker::Error::ArgumentError)
        end
      end

      context 'when the second argument is a Docker::Connection' do
        let(:id) { 'cb3f14a' }
        let(:connection) { Docker::Connection.new }
        let(:container) { subject.new(:id => id, :connection => connection) }

        it 'initializes the Container' do
          container.id.should == id
          container.connection.should == connection
        end
      end
    end
  end

  describe '#to_s' do
    let(:id) { 'bf119e2' }
    let(:connection) { Docker::Connection.new }
    let(:expected_string) do
      "Docker::Container { :id => #{id}, :connection => #{connection} }"
    end
    subject { described_class.new(:id => id, :connection => connection)  }

    its(:to_s) { should == expected_string }
  end

  describe '#created?' do
    context 'when the id is nil' do
      its(:created?) { should be_false }
    end

    context 'when the id is present' do
      subject { described_class.new(:id => 'a732ebf') }

      its(:created?) { should be_true }
    end
  end

  describe '#create!' do
    context 'when the Container has already been created' do
      subject { described_class.new(:id => '5e88b2a') }

      it 'raises an error' do
        expect { subject.create! }
            .to raise_error(Docker::Error::ContainerError)
      end
    end

    context 'when the body is not a Hash' do
      it 'raises an error' do
        expect { subject.create!(:not_a_hash) }
            .to raise_error(Docker::Error::ArgumentError)
      end
    end

    context 'when the Container does not yet exist and the body is a Hash' do
      context 'when the HTTP request does not return a 200' do
        before { Excon.stub({ :method => :post }, { :status => 400 }) }
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.create! }.to raise_error(Excon::Errors::BadRequest)
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

        it 'sets the id', :vcr do
          expect { subject.create!(options) }
              .to change { subject.id }
              .from(nil)
        end
      end
    end
  end

  describe '#json' do
    context 'when the Container has not been created' do
      it 'raises an error' do
        expect { subject.json }.to raise_error Docker::Error::ContainerError
      end
    end

    context 'when the Container has been created' do
      context 'when the HTTP response status is not 200' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :get }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.json }
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        let(:description) { subject.json }
        before { subject.create!('Cmd' => ['ls'], 'Image' => 'base') }

        it 'returns the description as a Hash', :vcr do
          description.should be_a(Hash)
          description['Id'].should start_with(subject.id)
        end
      end
    end
  end

  describe '#changes' do
    context 'when the Container has not been created' do
      it 'raises an error' do
        expect { subject.changes }
            .to raise_error Docker::Error::ContainerError
      end
    end

    context 'when the Container has been created' do
      context 'when the HTTP response status is not 200' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :get }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.changes }
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        let(:changes) { subject.changes }
        before do
          subject.create!('Cmd' => ['ls'], 'Image' => 'base')
          subject.start
          subject.wait
        end

        it 'returns the changes as an array', :vcr do
          changes.should be_a Array
          changes.should be_all { |change| change.is_a?(Hash) }
          changes.length.should_not be_zero
        end
      end
    end
  end

  describe '#export' do
    context 'when the Container has not been created' do
      it 'raises an error' do
        expect { subject.export { } }
            .to raise_error Docker::Error::ContainerError
      end
    end

    context 'when the Container has been created' do
      context 'when the HTTP response status is not 200' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :get }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.export { } }
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        before do
         subject.create!('Cmd' => ['ls'], 'Image' => 'base')
         subject.start
         subject.wait
        end

        it 'yields each chunk', :vcr do
          first = nil
          subject.export do |chunk|
            first = chunk
            break
          end
          first[257..262].should == "ustar\000" # Make sure the export is a tar.
        end
      end
    end
  end

  describe '#start' do
    context 'when the Container has not been created' do
      it 'raises an error' do
        expect { subject.start }.to raise_error Docker::Error::ContainerError
      end
    end

    context 'when the Container has been created' do
      context 'when the HTTP response status is not 200' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :post }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.start }
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        before { subject.create!('Cmd' => ['/usr/bin/sleep 10'],
                                 'Image' => 'base') }

        it 'starts the container', :vcr do
          subject.start
          described_class.all.map(&:id).should be_any { |id|
            id.start_with?(subject.id)
          }
        end
      end
    end
  end

  describe '#stop' do
    context 'when the Container has not been created' do
      it 'raises an error' do
        expect { subject.stop }.to raise_error Docker::Error::ContainerError
      end
    end

    context 'when the Container has been created' do
      context 'when the HTTP response status is not 204' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :post }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.stop }
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 204' do
        before { subject.create!('Cmd' => ['ls'], 'Image' => 'base') }

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
  end

  describe '#kill' do
    context 'when the Container has not been created' do
      it 'raises an error' do
        expect { subject.kill }.to raise_error Docker::Error::ContainerError
      end
    end

    context 'when the Container has been created' do
      context 'when the HTTP response status is not 204' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :post }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.kill }
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 204' do
        before { subject.create!('Cmd' => ['ls'], 'Image' => 'base') }

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
  end

  describe '#restart' do
    context 'when the Container has not been created' do
      it 'raises an error' do
        expect { subject.restart }.to raise_error Docker::Error::ContainerError
      end
    end

    context 'when the Container has been created' do
      context 'when the HTTP response status is not 204' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :post }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.restart }
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 204' do
        before { subject.create!('Cmd' => ['/usr/bin/sleep 50'],
                                 'Image' => 'base') }

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
  end

  describe '#wait' do
    context 'when the Container has not been created' do
      it 'raises an error' do
        expect { subject.wait }.to raise_error Docker::Error::ContainerError
      end
    end

    context 'when the Container has been created' do
      context 'when the HTTP response status is not 200' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :post }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.wait }
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        before { subject.create!('Cmd' => %w[tar nonsense],
                                 'Image' => 'base') }

        it 'waits for the command to finish', :vcr do
          subject.start
          subject.wait['StatusCode'].should == 64
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
            .to raise_error(Excon::Errors::InternalServerError)
      end
    end

    context 'when the HTTP response is a 200', :current do
      it 'materializes each Container into a Docker::Container', :vcr do
        subject.new.create!('Cmd' => ['ls'], 'Image' => 'base')
        subject.all(:all => true).should be_all { |container|
          container.is_a?(Docker::Container)
        }
        subject.all(:all => true).length.should_not be_zero
      end
    end
  end
end
