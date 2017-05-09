require 'spec_helper'

SingleCov.covered! uncovered: 11

describe Docker::Node, docker_1_12: true do
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

  before do
    Docker::Swarm.init(opts) if Docker.info['Swarm']['Cluster']['ID'].empty?
  end

  after do
    Docker::Swarm.leave(true)
  end

  describe '.nodes' do
    context 'show all swarm nodes' do
      let(:process) { subject.nodes }

      it 'returns an array of nodes' do
        expect(process).to be_a Array
      end

      it 'node is manager' do
        expect(process[0]['Spec']['Role']).to include('manager')
      end
    end
  end

  describe '.node' do
    context 'show single swarm node' do
      let(:process) { subject.node }

      it 'returns a node object' do
        expect(process).to be_a Docker::Node
      end

      it 'node info is a hash' do
        expect(process.info).to be_a Hash
      end
    end
  end
end