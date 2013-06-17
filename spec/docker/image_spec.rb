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
            .to raise_error(Docker::Error::ImageError)
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
          expect { subject.create! }.to raise_error(Excon::Errors::BadRequest)
        end
      end

      context 'when the HTTP request returns a 200' do
        let(:options) { { 'fromImage' => 'base' } }

        it 'sets the id', :vcr do
          pending
          expect { subject.create!(options) }
              .to change { subject.id }
              .from(nil)
        end
      end
    end
  end

  describe '#remove!' do
    context 'when the Image has not been created' do
      it 'raises an error' do
        expect { subject.remove! }.to raise_error Docker::Error::ImageError
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
          expect { subject.remove! }
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 204' do
        before { pending; subject.create!('fromImage' => 'base') }

        it 'waits for the command to finish', :vcr do
          pending
          subject.remove!
        end
      end
    end
  end

  describe "#insert" do
    context 'when the Image has not been created' do
      it 'raises an error' do
        expect { subject.insert }.to raise_error Docker::Error::ImageError
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
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        before { pending; subject.create!('fromImage' => 'base') }

        it 'waits for the command to finish', :vcr do
          pending
          subject.insert
        end
      end
    end
  end

  describe "#push" do
    context 'when the Image has not been created' do
      it 'raises an error' do
        expect { subject.push }.to raise_error Docker::Error::ImageError
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
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        before { pending; subject.create!('fromImage' => 'base') }

        it 'waits for the command to finish', :vcr do
          pending
          subject.push
        end
      end
    end
  end

  describe "#tag" do
    context 'when the Image has not been created' do
      it 'raises an error' do
        expect { subject.tag }.to raise_error Docker::Error::ImageError
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
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        before { pending; subject.create!('fromImage' => 'base') }

        it 'waits for the command to finish', :vcr do
          pending
          subject.tag
        end
      end
    end
  end

  describe "#json" do
    context 'when the Image has not been created' do
      it 'raises an error' do
        expect { subject.json }.to raise_error Docker::Error::ImageError
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
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        before { pending; subject.create!('fromImage' => 'base') }

        it 'waits for the command to finish', :vcr do
          pending
          subject.json
        end
      end
    end
  end

  describe "#history" do
    context 'when the Image has not been created' do
      it 'raises an error' do
        expect { subject.history }.to raise_error Docker::Error::ImageError
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
              .to raise_error(Excon::Errors::InternalServerError)
        end
      end

      context 'when the HTTP response status is 200' do
        before { pending; subject.create!('fromImage' => 'base') }

        it 'waits for the command to finish', :vcr do
          pending
          subject.history
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

    context 'when the HTTP response is a 200' do
      it 'materializes each Container into a Docker::Container', :vcr do
        pending
        subject.new.create!('fromImage' => 'base')
        subject.all(:all => true).should be_all { |image|
          image.is_a?(described_class)
        }
        subject.all(:all => true).length.should_not be_zero
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
            .to raise_error(Excon::Errors::InternalServerError)
      end
    end

    context 'when the HTTP response is a 200' do
      it 'materializes each Container into a Docker::Container', :vcr do
        pending
        subject.new.create!('fromImage' => 'base')
        subject.search('term' => 'sshd').should be_all { |image|
          image.is_a?(described_class)
        }
      end
    end
  end
end
