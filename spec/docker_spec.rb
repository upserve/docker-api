require 'spec_helper'

describe Docker do
  subject { Docker }

  it { should be_a Module }
  its(:port) { should == 4243 }
  its(:host) { should == 'http://localhost' }
  its(:connection) { should be_a Docker::Connection }

  describe '#reset_connection!' do
    before { subject.connection }
    it 'sets the @connection to nil' do
      expect { subject.reset_connection! }
          .to change { subject.instance_variable_get(:@connection) }
          .to nil
    end
  end

  [:port=, :host=].each do |method|
    describe "##{method}" do
      it 'calls #reset_connection! first' do
        subject.should_receive(:reset_connection!)
        subject.public_send(method, :value)
      end
    end
  end
end
