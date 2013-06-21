require 'spec_helper'

describe Docker::Image do
  describe '#initialize' do
    subject { described_class }

    context 'with no argument' do
      let(:image) { subject.new }

      it 'sets the id to nil' do
        image.id.should be_nil
      end

      it 'keeps the default Connection' do
        image.connection.should == Docker.connection
      end
    end

    context 'with an argument' do
      let(:id) { 'a7c2ee4' }
      let(:image) { subject.new(:id => id) }

      it 'sets the id to the argument' do
        image.id.should == id
      end

      it 'keeps the default Connection' do
        image.connection.should == Docker.connection
      end
    end

    context 'with two arguments' do
      context 'when the second argument is not a Docker::Connection' do
        let(:id) { 'abc123f' }
        let(:connection) { :not_a_connection }
        let(:image) { subject.new(:id => id, :connection => connection) }

        it 'raises an error' do
          expect { image }.to raise_error(Docker::Error::ArgumentError)
        end
      end

      context 'when the second argument is a Docker::Connection' do
        let(:id) { 'cb3f14a' }
        let(:connection) { Docker::Connection.new }
        let(:image) { subject.new(:id => id, :connection => connection) }

        it 'initializes the Image' do
          image.id.should == id
          image.connection.should == connection
        end
      end
    end
  end

  describe '#to_s' do
    let(:id) { 'bf119e2' }
    let(:connection) { Docker::Connection.new }
    let(:expected_string) do
      "Docker::Image { :id => #{id}, :connection => #{connection} }"
    end
    subject { described_class.new(:id => id, :connection => connection) }

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
    context 'when the Image has already been created' do
      subject { described_class.new(:id => '5e88b2a') }

      it 'raises an error' do
        expect { subject.create! }
            .to raise_error(Docker::Error::StateError)
      end
    end

    context 'when the body is not a Hash' do
      it 'raises an error' do
        expect { subject.create!(:not_a_hash) }
            .to raise_error(Docker::Error::ArgumentError)
      end
    end

    context 'when the Image does not yet exist and the body is a Hash' do
      context 'when the HTTP request does not return a 200' do
        before { Excon.stub({ :method => :post }, { :status => 400 }) }
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.create! }.to raise_error(Docker::Error::ClientError)
        end
      end

      context 'when the HTTP request returns a 200' do
        it 'sets the id', :vcr do
          expect { subject.create!('fromRepo' => 'base', 'fromSrc' => '-') }
              .to change { subject.id }
              .from(nil)
        end
      end
    end
  end

  describe '#remove' do
    context 'when the Image has not been created' do
      it 'raises an error' do
        expect { subject.remove }.to raise_error Docker::Error::StateError
      end
    end

    context 'when the Image has been created' do
      context 'when the HTTP response status is not 204' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :delete }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.remove }
              .to raise_error(Docker::Error::ServerError)
        end
      end

      context 'when the HTTP response status is 204' do
        before { subject.create!('fromRepo' => 'base', 'fromSrc' => '-') }

        it 'nils out the id', :vcr do
          expect { subject.remove }
              .to change { subject.id }
              .to nil
        end
      end
    end
  end

  describe "#insert" do
    context 'when the Image has not been created' do
      it 'raises an error' do
        expect { subject.insert }.to raise_error Docker::Error::StateError
      end
    end

    context 'when the Image has been created' do
      context 'when the HTTP response status is not 200' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :post }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.insert }
              .to raise_error(Docker::Error::ServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        subject { described_class.build('from base') }
        let(:new_image) { subject.insert(:path => '/stallman',
                                         :url => 'http://stallman.org') }
        let(:container) { Docker::Container.new }
        let(:ls_output) do
          container.tap(&:start)
                   .attach(:stream => true, :stdout => true)
                   .split("\n")
        end
        before { container.create!('Image' => new_image.id, 'Cmd' => %w[ls /]) }

        it 'inserts the url\'s file into a new Image', :vcr do
          ls_output.should include('stallman')
        end
      end
    end
  end

  describe "#push" do
    context 'when the Image has not been created' do
      it 'raises an error' do
        expect { subject.push }.to raise_error Docker::Error::StateError
      end
    end

    context 'when the Image has been created' do
      context 'when the HTTP response status is not 200' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :post }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.push }
              .to raise_error(Docker::Error::ServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        it 'pushes the Image', :vcr do
          pending 'I don\'t want to push the Image to the Docker Registry'
          subject.create!('fromRepo' => 'base', 'fromSrc' => '-')
          subject.push
        end
      end
    end
  end

  describe "#tag" do
    context 'when the Image has not been created' do
      it 'raises an error' do
        expect { subject.tag }.to raise_error Docker::Error::StateError
      end
    end

    context 'when the Image has been created' do
      context 'when the HTTP response status is not 200' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :post }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.tag }
              .to raise_error(Docker::Error::ServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        before { subject.create!('fromRepo' => 'base', 'fromSrc' => '-') }

        it 'tags the image with the repo name', :vcr do
          expect { subject.tag(:repo => 'base2', :force => true) }
              .to_not raise_error
        end
      end
    end
  end

  describe "#json" do
    context 'when the Image has not been created' do
      it 'raises an error' do
        expect { subject.json }.to raise_error Docker::Error::StateError
      end
    end

    context 'when the Image has been created' do
      context 'when the HTTP response status is not 200' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :get }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.json }
              .to raise_error(Docker::Error::ServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        let(:json) { subject.json }
        before { subject.create!('fromRepo' => 'base', 'fromSrc' => '-') }

        it 'returns additional information about image image', :vcr do
          json.should be_a Hash
          json['id'].should start_with subject.id
          json['comment'].should == 'Imported from -'
        end
      end
    end
  end

  describe "#history" do
    context 'when the Image has not been created' do
      it 'raises an error' do
        expect { subject.history }.to raise_error Docker::Error::StateError
      end
    end

    context 'when the Image has been created' do
      context 'when the HTTP response status is not 200' do
        before do
          subject.stub(:created?).and_return(true)
          Excon.stub({ :method => :get }, { :status => 500 })
        end
        after { Excon.stubs.shift }

        it 'raises an error' do
          expect { subject.history }
              .to raise_error(Docker::Error::ServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        let(:history) { subject.history }
        before { subject.create!('fromRepo' => 'base', 'fromSrc' => '-') }

        it 'returns the history of the Image', :vcr do
          history.should be_a Array
          history.length.should_not be_zero
          history.should be_all { |elem| elem.is_a? Hash }
        end
      end
    end
  end

  describe '#create_from_file' do
    context 'when the file does not exist' do
      let(:file) { '/lol/not/a/file' }

      it 'raises an error' do
        expect { subject.create_from_file(file) }
            .to raise_error Errno::ENOENT
      end
    end

    context 'when the file does exist' do
      let(:filename) { 'docker-export.tar' }
      let(:mock_file) { mock(:file) }
      before { File.stub(:open).with(filename, 'r').and_yield(mock_file) }

      context 'when the Image has already been created' do
        before { subject.stub(:created?).and_return(true) }

        it 'raises an error' do
          expect { subject.create_from_file(filename) }
              .to raise_error Docker::Error::StateError
        end
      end

      context 'when the Image has not been created' do
        it 'creates the Image', :vcr do
          mock_file.stub(:read).and_return('.')
          expect { subject.create_from_file(filename) }
              .to change { subject.id  }
              .from nil
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
      let(:images) { subject.all(:all => true) }
      before { subject.new.create!('fromRepo' => 'base', 'fromSrc' => '-') }
      it 'materializes each Container into a Docker::Container', :vcr do
        images.should be_all { |image|
          !image.id.nil? && image.is_a?(described_class)
        }
        images.length.should_not be_zero
      end
    end
  end

  describe '.search' do
    subject { described_class }

    context 'when the HTTP response is not a 200' do
      before { Excon.stub({ :method => :get }, { :status => 500 }) }
      after { Excon.stubs.shift }

      it 'raises an error' do
        expect { subject.search }
            .to raise_error(Docker::Error::ServerError)
      end
    end

    context 'when the HTTP response is a 200' do
      it 'materializes each Container into a Docker::Container', :vcr do
        subject.new.create!('fromRepo' => 'base', 'fromSrc' => '-')
        subject.search('term' => 'sshd').should be_all { |image|
          !image.id.nil? && image.is_a?(described_class)
        }
      end
    end
  end

  describe '.build' do
    subject { described_class }
    context 'with an invalid Dockerfile' do
      it 'throws a UnexpectedResponseError', :vcr do
        expect { subject.build('lololol') }
            .to raise_error(Docker::Error::UnexpectedResponseError)
      end
    end

    context 'with a valid Dockerfile' do
      let(:image) { subject.build("from base\n") }

      it 'builds an image', :vcr do
        image.should be_a Docker::Image
        image.id.should_not be_nil
        image.connection.should be_a Docker::Connection
      end
    end
  end

  describe '.build_from_file' do
    subject { described_class }

    context 'with a valid Dockerfile' do
      let(:file_name) do
        File.join(File.dirname(__FILE__), '..', 'fixtures', 'Dockerfile')
      end
      let(:docker_file) { File.new(file_name) }
      let(:image) { subject.build_from_file(docker_file) }
      let(:container) do
        Docker::Container.new.create!('Image' => image.id,
                                      'Cmd' => %w[cat /Dockerfile])
      end
      let(:output) { container.tap(&:start)
                              .attach(:stream => true, :stdout => true) }

      it 'builds the image', :vcr do
        output.should == docker_file.read
      end
    end
  end
end
