# frozen_string_literal: true

require 'spec_helper'

# Skip on non-Windows since the file itself requires `ffi` and Win32 libs.
if Gem.win_platform?
  require 'docker/npipe_socket'

  describe Docker::NPipeSocket do
    describe '.normalize_pipe_path' do
      subject { described_class.method(:normalize_pipe_path) }

      it 'returns nil for nil input' do
        expect(subject.call(nil)).to be_nil
      end

      it 'returns nil for empty input' do
        expect(subject.call('')).to be_nil
      end

      it 'normalizes a URI-style path' do
        expect(subject.call('//./pipe/docker_engine')).to eq('\\\\.\\pipe\\docker_engine')
      end

      it 'normalizes a path with extra leading slashes (from npipe://// URL)' do
        expect(subject.call('////./pipe/docker_engine')).to eq('\\\\.\\pipe\\docker_engine')
      end

      it 'is a no-op for a canonical Windows path' do
        expect(subject.call('\\\\.\\pipe\\docker_engine')).to eq('\\\\.\\pipe\\docker_engine')
      end

      it 'prefixes \\\\.\\ when missing' do
        expect(subject.call('/pipe/docker_engine')).to eq('\\\\.\\pipe\\docker_engine')
      end
    end
  end
end
