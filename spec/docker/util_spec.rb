require 'spec_helper'
require 'tempfile'

describe Docker::Util do
  subject { described_class }

  describe '.parse_json' do
    subject { described_class.parse_json(arg) }

    context 'when the argument is nil' do
      let(:arg) { nil }

      it { should be_nil }
    end

    context 'when the argument is empty' do
      let(:arg) { '' }

      it { should be_nil }
    end

    context 'when the argument is \'null\'' do
      let(:arg) { 'null' }

      it { should be_nil }
    end

    context 'when the argument is not valid JSON' do
      let(:arg) { '~~lol not valid json~~' }

      it 'raises an error' do
        expect { subject }.to raise_error Docker::Error::UnexpectedResponseError
      end
    end

    context 'when the argument is valid JSON' do
      let(:arg) { '{"yolo":"swag"}' }

      it 'parses the JSON into a Hash' do
        expect(subject).to eq 'yolo' => 'swag'
      end
    end
  end

  describe '.fix_json' do
    let(:response) { '{"this":"is"}{"not":"json"}' }
    subject { Docker::Util.fix_json(response) }

    it 'fixes the "JSON" response that Docker returns' do
      expect(subject).to eq [
        {
          'this' => 'is'
        },
        {
          'not' => 'json'
        }
      ]
    end
  end

  describe '.create_dir_tar' do
    attr_accessor :tmpdir

    let(:tar) { subject.create_dir_tar tmpdir }

    around do |example|
      Dir.mktmpdir do |tmpdir|
        self.tmpdir = tmpdir
        example.call
        FileUtils.rm tar
      end
    end

    it 'creates a tarball' do
      tar = subject.create_dir_tar tmpdir
      expect(files_in_tar(tar)).to eq []
    end

    it 'packs regular files' do
      File.write("#{tmpdir}/foo", 'bar')
      expect(files_in_tar(tar)).to eq ['foo']
    end

    it 'packs nested files, but not directory entries' do
      FileUtils.mkdir("#{tmpdir}/foo")
      File.write("#{tmpdir}/foo/bar", 'bar')
      expect(files_in_tar(tar)).to eq ['foo/bar']
    end

    describe ".dockerignore" do
      it 'ignores files' do
        File.write("#{tmpdir}/foo", 'bar')
        File.write("#{tmpdir}/baz", 'bar')

        File.write("#{tmpdir}/.dockerignore", "foo")

        expect(files_in_tar(tar)).to eq ['.dockerignore', 'baz']
      end

      it 'ignores folders' do
        FileUtils.mkdir("#{tmpdir}/foo")
        File.write("#{tmpdir}/foo/bar", 'bar')

        File.write("#{tmpdir}/.dockerignore", "foo")

        expect(files_in_tar(tar)).to eq ['.dockerignore']
      end

      it 'ignores based on wildcards' do
        File.write("#{tmpdir}/bar", 'bar')
        File.write("#{tmpdir}/baz", 'bar')

        File.write("#{tmpdir}/.dockerignore", "*z")

        expect(files_in_tar(tar)).to eq ['.dockerignore', 'bar']
      end

      it 'ignores comments' do
        File.write("#{tmpdir}/foo", 'bar')
        File.write("#{tmpdir}/baz", 'bar')

        File.write("#{tmpdir}/.dockerignore", "# nothing here\nfoo")

        expect(files_in_tar(tar)).to eq ['.dockerignore', 'baz']
      end

      it 'ignores whitespace' do
        File.write("#{tmpdir}/foo", 'bar')
        File.write("#{tmpdir}/baz", 'bar')

        File.write("#{tmpdir}/.dockerignore", "foo   \n   \n\n")

        expect(files_in_tar(tar)).to eq ['.dockerignore', 'baz']
      end

      it 'ignores multiple patterns' do
        File.write("#{tmpdir}/foo", 'bar')
        File.write("#{tmpdir}/baz", 'bar')
        File.write("#{tmpdir}/zig", 'bar')

        File.write("#{tmpdir}/.dockerignore", "fo*\nba*")

        expect(files_in_tar(tar)).to eq ['.dockerignore', 'zig']
      end
    end
  end

  describe '.build_auth_header' do
    subject { described_class }

    let(:credentials) {
      {
        :username      => 'test',
        :password      => 'password',
        :email         => 'test@example.com',
        :serveraddress => 'https://registry.com/'
      }
    }
    let(:credential_string) { credentials.to_json }
    let(:encoded_creds) { Base64.encode64(credential_string).gsub(/\n/, '') }
    let(:expected_header) {
      {
        'X-Registry-Auth' => encoded_creds
      }
    }

    context 'given credentials as a Hash' do
      it 'returns an X-Registry-Auth header encoded' do
        expect(subject.build_auth_header(credentials)).to eq(expected_header)
      end
    end

    context 'given credentials as a String' do
      it 'returns an X-Registry-Auth header encoded' do
        expect(
          subject.build_auth_header(credential_string)
        ).to eq(expected_header)
      end
    end
  end

  describe '.build_config_header' do
    subject { described_class }

    let(:credentials) {
      {
        :username      => 'test',
        :password      => 'password',
        :email         => 'test@example.com',
        :serveraddress => 'https://registry.com/'
      }
    }

    let(:credentials_object) {
      {
        :'https://registry.com/' => {
          :username => 'test',
          :password => 'password',
          :email    => 'test@example.com',
        }
      }.to_json
    }

    let(:encoded_creds) { Base64.encode64(credentials_object).gsub(/\n/, '') }
    let(:expected_header) {
      {
        'X-Registry-Config' => encoded_creds
      }
    }

    context 'given credentials as a Hash' do
      it 'returns an X-Registry-Config header encoded' do
        expect(subject.build_config_header(credentials)).to eq(expected_header)
      end
    end

    context 'given credentials as a String' do
      it 'returns an X-Registry-Config header encoded' do
        expect(
          subject.build_config_header(credentials.to_json)
        ).to eq(expected_header)
      end
    end
  end

  describe '.filesystem_permissions' do
    it 'returns the permissions on a file' do
      file = Tempfile.new('test_file')
      file.close
      expected_permissions = 0600
      File.chmod(expected_permissions, file.path)

      actual_permissions = subject.filesystem_permissions(file.path)

      file.unlink
      expect(actual_permissions).to eql(expected_permissions)
    end
  end

  def files_in_tar(tar)
    Gem::Package::TarReader.new(tar) { |content| return content.map(&:full_name).sort }
  end
end
