require 'spec_helper'

describe Docker do
  subject { Docker }

  it { should be_a Module }
  its(:options) { should == { :port => 4243 } }
  its(:url) { should == 'http://localhost' }
  its(:connection) { should be_a Docker::Connection }

  describe '#reset_connection!' do
    before { subject.connection }
    it 'sets the @connection to nil' do
      expect { subject.reset_connection! }
          .to change { subject.instance_variable_get(:@connection) }
          .to nil
    end
  end

  [:options=, :url=].each do |method|
    describe "##{method}" do
      it 'calls #reset_connection!' do
        subject.should_receive(:reset_connection!)
        subject.public_send(method, {})
      end
    end
  end
end
