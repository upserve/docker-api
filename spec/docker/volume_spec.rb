require 'spec_helper'

# WARNING if you're re-recording any of these VCRs, you must be running the
# Docker daemon and have the base Image pulled.
describe Docker::Volume do

name = "ArbitraryNameForTheRakeTestVolume"

  describe '#create' do
    context 'creating a volume' do
      it 'check if volume exists', :vcr do
        result = Docker::Volume.create(name).instance_variable_get(:@id)
        expect(result).to eq(name)
      end
    end
  end

  describe '#get' do
    context 'getting a volume' do
      it 'check volume details', :vcr do
        result = Docker::Volume.get(name).instance_variable_get(:@id)
        expect(result).to eq(name)
      end
    end
  end

  describe '#all' do
    context 'getting volume list' do
      it 'check if volume number is more than 1', :vcr do
        result = Docker::Volume.all.length
        expect(result).to be >1
      end
    end
  end

  describe '#remove' do
    context 'removing a volume' do
      it 'check if volume can be deleted', :vcr do
        result = Docker::Volume.remove(name)
        expect(result).to be_nil
      end
    end
  end

end
