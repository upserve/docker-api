require 'spec_helper'

SingleCov.covered! uncovered: 20

describe Docker::Swarm, docker_1_12: true do
  subject { described_class }

  let(:opts) do
    {
        "ListenAddr" => "0.0.0.0:2377",
        "AdvertiseAddr" => "127.0.0.1:2377",
        "ForceNewCluster" => false,
        "Spec" => {
            "Orchestration" => {},
            "Raft" => {},
            "Dispatcher" => {},
            "CAConfig" => {},
            "EncryptionConfig" => {
                "AutoLockManagers" => false
            }
        }
    }
  end

  describe '.init' do
    before do
      Docker::Swarm.leave(true) unless Docker.info['Swarm']['Cluster']['ID'].empty?
    end

    context 'Initialize a new swarm' do
      let(:process) { subject.init(opts) }

      it 'returns the node id' do
        expect(process).to be_a String
      end
    end

    after do
      Docker::Swarm.leave(true)
    end
  end

  describe '.inspect' do
    before do
      Docker::Swarm.init(opts) if Docker.info['Swarm']['Cluster']['ID'].empty?
    end

    context 'Inspect the swarm' do
      let(:process) { subject.inspect }

      it 'should be a Docker::Swarm object' do
        expect(process).to be_a Docker::Swarm
        expect(process.info).to be_a Hash
      end
    end
  end

  describe '.leave' do
    before do
      Docker::Swarm.init(opts) if Docker.info['Swarm']['Cluster']['ID'].empty?
    end

    context 'Leave the swarm' do
      let(:process) { subject.leave(true) }

      it 'return true' do
        expect(process).to be nil
      end
    end
  end
end