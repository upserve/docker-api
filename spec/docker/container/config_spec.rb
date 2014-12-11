require 'spec_helper'

describe Docker::Container::Config do
  let(:cfg) { described_class.new }

  describe '#initialize' do
    it 'sets up options' do
      expect(cfg.options).to eql({
        'HostConfig' => {}
      })
    end

    it 'accepts an initial hash' do
      cfg = described_class.new('Image' => 'ubuntu:12.04', 'Cmd' => ['ls'])
      expect(cfg.options).to eql({
        'Image' => 'ubuntu:12.04',
        'Cmd' => ['ls'],
        'HostConfig' => {}
      })
    end
  end

  describe '.from_cli' do
    let(:cli) {
      "docker run --privileged -p 8080:80 -v /container busybox " \
      "--volumes-from=\"container1\" --volumes-from=\"container2:ro\" " \
      "/my_script.sh bar -p foo --option=\"has spaces\""
    }

    let(:expected) {
      described_class.new(
        'Image' => 'busybox',
        'ExposedPorts' => {
          '80/tcp' => {}
        },
        'Volumes' => {
          '/container' => {}
        },
        'Cmd' => ['/my_script.sh', 'bar', '-p', 'foo', '--option=has spaces'],
        'HostConfig' => {
          'Privileged' => true,
          'PortBindings' => {
            '80/tcp' => [
              {
                'HostPort' => '8080',
                'HostIp' => ''
              }
            ]
          },
          'Binds' => [],
          'VolumesFrom' => ['container1', 'container2:ro']
        }
      )
    }

    it 'parses a string and captures the necessary parameters' do
      expect(described_class.from_cli(cli).options).to eql expected.options
    end
  end

  describe '#to_hash' do
    it 'returns the options hash' do
      expect(cfg.to_hash).to eql({
        'HostConfig' => {}
      })
    end
  end

  describe '#to_json' do
    it 'returns the options hash as JSON string' do
      expect(cfg.to_json).to eql('{"HostConfig":{}}')
    end
  end

  describe '#add_host' do
    it 'returns itself' do
      expect(cfg.add_host('host:ip')).to be_a described_class
    end

    [:extra_host, :extra_hosts, :add_hosts].each do |method|
      it "is accessible via ##{method}" do
        expect(cfg.method(method)).to eql cfg.method(:add_host)
      end
    end

    it 'sets ExtraHosts under HostConfig' do
      cfg.add_host('host:ip')
      cfg.add_host('host1:ip1', 'host2:ip2')

      result = cfg.options['HostConfig']['ExtraHosts']
      expect(result).to match_array ['host:ip', 'host1:ip1', 'host2:ip2']
    end
  end

  describe '#attach' do
    it 'returns itself' do
      expect(cfg.attach('stdin')).to be_a described_class
    end

    it 'is accessible via #a' do
      expect(cfg.method(:a)).to eql cfg.method(:attach)
    end

    it 'sets Attach*' do
      cfg.attach('stdin')
      cfg.attach('stdout', 'stderr')

      expect(cfg.options['AttachStdin']).to eql true
      expect(cfg.options['AttachStdout']).to eql true
      expect(cfg.options['AttachStderr']).to eql true
    end
  end

  describe '#cap_add' do
    it 'returns itself' do
      expect(cfg.cap_add('cap')).to be_a described_class
    end

    [:add_capability, :add_capabilities].each do |method|
      it "is accessible via ##{method}" do
        expect(cfg.method(method)).to eql cfg.method(:cap_add)
      end
    end

    it 'adds capability to CapAdd under HostConfig' do
      cfg.cap_add('cap1')
      cfg.cap_add('cap2', 'cap3')

      expect(cfg.options['HostConfig']['CapAdd'])
        .to match_array ['cap1', 'cap2', 'cap3']
    end
  end

  describe '#cap_drop' do
    it 'returns itself' do
      expect(cfg.cap_drop('cap')).to be_a described_class
    end

    [:drop_capability, :drop_capabilities].each do |method|
      it "is accessible via ##{method}" do
        expect(cfg.method(method)).to eql cfg.method(:cap_drop)
      end
    end

    it 'adds capability to CapDrop under HostConfig' do
      cfg.cap_drop('cap1')
      cfg.cap_drop('cap2', 'cap3')

      expect(cfg.options['HostConfig']['CapDrop'])
        .to match_array ['cap1', 'cap2', 'cap3']
    end
  end

  describe '#cidfile' do
    it 'returns itself' do
      expect(cfg.cidfile('/myfile')).to be_a described_class
    end

    it 'sets ContainerIDFile' do
      cfg.cidfile('/myfile')
      expect(cfg.options['ContainerIDFile']).to eql '/myfile'
    end
  end

  describe '#cmd' do
    it 'returns itself' do
      expect(cfg.cmd('true')).to be_a described_class
    end

    it 'is accessible via #command' do
      expect(cfg.method(:command)).to eql cfg.method(:cmd)
    end

    it 'converts a String into Shellwords' do
      cfg.cmd('/my_script.sh param1 -p "param has spaces"')
      expect(cfg.options['Cmd'])
        .to eql ['/my_script.sh', 'param1', '-p', 'param has spaces']
    end

    it 'sets Cmd' do
      cfg.cmd('/my_script.sh', 'param1', '-p', 'param has spaces')
      expect(cfg.options['Cmd'])
        .to eql ['/my_script.sh', 'param1', '-p', 'param has spaces']
    end
  end

  describe '#cpu_shares' do
    it 'returns itself' do
      expect(cfg.cpu_shares(512)).to be_a described_class
    end

    it 'is accessible via #c' do
      expect(cfg.method(:c)).to eql cfg.method(:cpu_shares)
    end

    it 'sets CpuShares' do
      cfg.cpu_shares(512)
      expect(cfg.options['CpuShares']).to eql 512
    end

    it 'converts String to Fixnum' do
      cfg.cpu_shares('512')
      expect(cfg.options['CpuShares']).to eql 512
    end
  end

  describe '#cpuset' do
    it 'returns itself' do
      expect(cfg.cpuset('0,1')).to be_a described_class
    end

    it 'sets Cpuset' do
      cfg.cpuset('0,1')
      expect(cfg.options['Cpuset']).to eql '0,1'
    end
  end

  describe '#detach' do
    it 'returns itself' do
      expect(cfg.detach).to be_a described_class
    end

    it 'is accessible via #d' do
      expect(cfg.method(:d)).to eql cfg.method(:detach)
    end

    it 'sets Attach*, Tty and StdinOnce to false' do
      cfg.detach
      expect(cfg.options['AttachStdin']).to eql false
      expect(cfg.options['AttachStdout']).to eql false
      expect(cfg.options['AttachStderr']).to eql false
      expect(cfg.options['Tty']).to eql false
      expect(cfg.options['StdinOnce']).to eql false
    end
  end

  describe '#device' do
    it 'returns itself' do
      expect(cfg.device('/dev:/dev')).to be_a described_class
    end

    it 'is accessible via #devices' do
      expect(cfg.method(:devices)).to eql cfg.method(:device)
    end

    it 'add device to Devices under HostConfig' do
      cfg.device('/foo:/bar')
      cfg.device('/dev:/opts', '/fus:/ro:dah')
      expect(cfg.options['HostConfig']['Devices']).to match_array [
        {
          'PathOnHost' => '/foo',
          'PathInContainer' => '/bar',
          'CgroupPermissions' => 'rwm'
        },
        {
          'PathOnHost' => '/dev',
          'PathInContainer' => '/opts',
          'CgroupPermissions' => 'rwm'
        },
        {
          'PathOnHost' => '/fus',
          'PathInContainer' => '/ro',
          'CgroupPermissions' => 'dah'
        }
      ]
    end
  end

  describe '#dns' do
    it 'returns itself' do
      expect(cfg.dns('8.8.8.8')).to be_a described_class
    end

    it 'adds dns to Dns under HostConfig' do
      cfg.dns('1')
      cfg.dns('2', '3')
      expect(cfg.options['HostConfig']['Dns']).to match_array ['1', '2', '3']
    end
  end

  describe '#dns_search' do
    it 'returns itself' do
      expect(cfg.dns_search('8.8.8.8')).to be_a described_class
    end

    it 'adds dns to DnsSearch under HostConfig' do
      cfg.dns_search('1')
      cfg.dns_search('2', '3')
      expect(cfg.options['HostConfig']['DnsSearch'])
        .to match_array ['1', '2', '3']
    end
  end

  describe '#env' do
    it 'returns itself' do
      expect(cfg.env('FAKE=fake')).to be_a described_class
    end

    it 'is accesible via #e' do
      expect(cfg.method(:e)).to eql cfg.method(:env)
    end

    it 'adds env variable to Env' do
      allow(ENV).to receive(:[]).with('FOO').and_return('bar')
      cfg.env('HELLO=world')
      cfg.env('FOO', 'DOCKER=rekcod')
      expect(cfg.options['Env']).to match_array [
        'HELLO=world',
        'FOO=bar',
        'DOCKER=rekcod'
      ]
    end
  end

  describe '#env_file' do
    include_context "local paths"
    let(:env_one) {
      File.join(project_dir, 'spec', 'fixtures', 'env_file', 'one')
    }
    let(:env_two) {
      File.join(project_dir, 'spec', 'fixtures', 'env_file', 'two')
    }
    let(:env_three) {
      File.join(project_dir, 'spec', 'fixtures', 'env_file', 'three')
    }

    it 'returns itself' do
      expect(cfg.env_file(env_one)).to be_a described_class
    end

    it 'is accessible via #env_files' do
      expect(cfg.method(:env_files)).to eql cfg.method(:env_file)
    end

    it 'fails when file doesn\'t exist' do
      expect{ cfg.env_file('/nope') }.to raise_error ArgumentError
    end

    it 'reads the files and adds the values to Env' do
      allow(ENV).to receive(:[]).with('FOO').and_return('bar')
      cfg.env_file(env_one, env_two)
      cfg.env_file(env_three)
      expect(cfg.options['Env']).to match_array [
        'HELLO=world',
        'DEV=opts',
        'FOO=bar',
        'FUS=ro dah'
      ]
    end
  end

  describe '#expose' do
    it 'returns itself' do
      expect(cfg.expose('80')).to be_a described_class
    end

    [:expose_port, :expose_ports].each do |method|
      it "is accessible via ##{method}" do
        expect(cfg.method(method)).to eql cfg.method(:expose)
      end
    end

    it 'adds the ports to ExposedPorts' do
      cfg.expose('1', '2', '3')
      cfg.expose('4', '5-7')
      expect(cfg.options['ExposedPorts']).to eql({
        '1/tcp' => {},
        '2/tcp' => {},
        '3/tcp' => {},
        '4/tcp' => {},
        '5/tcp' => {},
        '6/tcp' => {},
        '7/tcp' => {}
      })
    end
  end

  describe '#hostname' do
    it 'returns itself' do
      expect(cfg.hostname('localhost')).to be_a described_class
    end

    it 'is accessible via #h' do
      expect(cfg.method(:h)).to eql cfg.method(:hostname)
    end

    it 'sets Hostname' do
      cfg.hostname('foo')
      expect(cfg.options['Hostname']).to eql 'foo'
    end
  end

  describe '#image' do
    it 'returns itself' do
      expect(cfg.image('ubuntu:12.04')).to be_a described_class
    end

    it 'sets Image' do
      cfg.image('ubuntu:12.04')
      expect(cfg.options['Image']).to eql 'ubuntu:12.04'
    end
  end

  describe '#interactive' do
    it 'returns itself' do
      expect(cfg.interactive).to be_a described_class
    end

    it 'is accessible via #i' do
      expect(cfg.method(:i)).to eql cfg.method(:interactive)
    end

    it 'sets AttachStdin to true' do
      cfg.interactive
      expect(cfg.options['AttachStdin']).to eql true
    end
  end

  describe '#link' do
    it 'returns itself' do
      expect(cfg.link('name:alias')).to be_a described_class
    end

    it 'is accessible via #links' do
      expect(cfg.method(:links)).to eql cfg.method(:link)
    end

    it 'adds links to Links under HostConfig' do
      cfg.link('ross:rachel')
      cfg.link('lily:marshall', 'batman:robin')
      expect(cfg.options['HostConfig']['Links']).to match_array [
        'ross:rachel',
        'lily:marshall',
        'batman:robin'
      ]
    end
  end

  describe '#lxc_conf' do
    it 'returns itself' do
      expect(cfg.lxc_conf('lxc = nope')).to be_a described_class
    end

    it 'adds conf to LxcConf under HostConfig' do
      cfg.lxc_conf('foo=bar')
      cfg.lxc_conf('much=wow', 'so=weird')
      expect(cfg.options['HostConfig']['LxcConf']).to eql({
        'foo' => 'bar',
        'much' => 'wow',
        'so' => 'weird'
      })
    end
  end

  describe '#memory' do
    it 'returns itself' do
      expect(cfg.memory('9000k')).to be_a described_class
    end

    it 'sets Memory to byte-value of memory string' do
      cfg.memory('1b')
      expect(cfg.options['Memory']).to eql 1

      cfg.memory('1k')
      expect(cfg.options['Memory']).to eql 1000

      cfg.memory('1m')
      expect(cfg.options['Memory']).to eql 1000000

      cfg.memory('1g')
      expect(cfg.options['Memory']).to eql 1000000000
    end
  end

  describe '#name' do
    it 'returns itself' do
      expect(cfg.name('bob')).to be_a described_class
    end

    it 'sets name' do
      cfg.name('bob')
      expect(cfg.options['name']).to eql 'bob'
    end
  end

  describe '#net' do
    it 'returns itself' do
      expect(cfg.net('bridge')).to be_a described_class
    end

    it 'raises error if invalid mode is specified' do
      expect{ cfg.net('invalid') }.to raise_error ArgumentError
    end

    it 'raises error if name or id isn\'t specified with container' do
      expect{ cfg.net('container') }.to raise_error ArgumentError
    end

    it 'set NetworkMode under HostConfig' do
      cfg.net('bridge')
      expect(cfg.options['HostConfig']['NetworkMode']).to eql 'bridge'
    end
  end

  describe '#privileged' do
    it 'returns itself' do
      expect(cfg.privileged).to be_a described_class
    end

    it 'sets Privileged to true under HostConfig' do
      cfg.privileged
      expect(cfg.options['HostConfig']['Privileged']).to eql true
    end
  end

  describe '#publish' do
    it 'returns itself' do
      expect(cfg.publish('8080:80')).to be_a described_class
    end

    it 'adds port to ExposedPorts and PortBindings under HostConfig' do
      cfg.publish('8080:80', '8081:80')
      cfg.publish('3306/udp', '127.0.0.1:8443:443')
      expect(cfg.options['ExposedPorts']).to eql({
        '80/tcp' => {},
        '3306/udp' => {},
        '443/tcp' => {}
      })
      expect(cfg.options['HostConfig']['PortBindings']).to eql({
        '80/tcp' => [
          {
            'HostPort' => '8080',
            'HostIp' => ''
          },
          {
            'HostPort' => '8081',
            'HostIp' => ''
          }
        ],
        '3306/udp' => [{
          'HostPort' => '',
          'HostIp' => ''
        }],
        '443/tcp' => [{
          'HostPort' => '8443',
          'HostIp' => '127.0.0.1'
        }]
      })
    end
  end

  describe '#publish_all' do
    it 'returns itself' do
      expect(cfg.publish_all).to be_a described_class
    end

    [:P, :publish_all_ports].each do |method|
      it "is accessible via ##{method}" do
        expect(cfg.method(method)).to eql cfg.method(:publish_all)
      end
    end

    it 'sets PublishAllPorts under HostConfig to true' do
      cfg.publish_all
      expect(cfg.options['HostConfig']['PublishAllPorts']).to eql true
    end
  end

  describe '#restart' do
    it 'returns itself' do
      expect(cfg.restart('no')).to be_a described_class
    end

    it 'is accessible via #restart_policy' do
      expect(cfg.method(:restart_policy)).to eql cfg.method(:restart)
    end

    it 'raises an error if you specify MaxRetryCount when not supposed to' do
      expect{cfg.restart('always:4') }.to raise_error ArgumentError
    end

    it 'raises an error if invalid policy is provided' do
      expect{ cfg.restart('invalid') }.to raise_error ArgumentError
    end

    it 'sets RestartPolicy under HostConfig' do
      cfg.restart('always')
      expect(cfg.options['HostConfig']['RestartPolicy']).to eql({
        'Name' => 'always',
        'MaximumRetryCount' => 0
      })

      cfg.restart('on-failure:4')
      expect(cfg.options['HostConfig']['RestartPolicy']).to eql({
        'Name' => 'on-failure',
        'MaximumRetryCount' => 4
        })
    end
  end

  describe '#security_opt' do
    it 'returns itself' do
      expect(cfg.security_opt('cake')).to be_a described_class
    end

    it 'adds options to SecurityOpt under HostConfig' do
      cfg.security_opt('a')
      cfg.security_opt('b', 'c')
      expect(cfg.options['HostConfig']['SecurityOpt']).to match_array %w(a b c)
    end
  end

  describe '#tty' do
    it 'returns itself' do
      expect(cfg.tty).to be_a described_class
    end

    it 'is accessible via #t' do
      expect(cfg.method(:t)).to eql cfg.method(:tty)
    end

    it 'sets Tty to true' do
      cfg.tty
      expect(cfg.options['Tty']).to eql true
    end
  end

  describe '#user' do
    it 'returns itself' do
      expect(cfg.user('user')).to be_a described_class
    end

    it 'is accessible via #u' do
      expect(cfg.method(:u)).to eql cfg.method(:user)
    end

    it 'sets User' do
      cfg.user('user')
      expect(cfg.options['User']).to eql 'user'
    end
  end

  describe '#volume' do
    it 'returns itself' do
      expect(cfg.volume('/host:/container')).to be_a described_class
    end

    [:v, :volumes].each do |method|
      it "is accessible via ##{method}" do
        expect(cfg.method(method)).to eql cfg.method(:volume)
      end
    end

    it 'raises an error if you try to bind to root' do
      expect{ cfg.volume('/') }.to raise_error ArgumentError
      expect{ cfg.volume('/host:/') }.to raise_error ArgumentError
    end

    it 'adds volume to Volumes and binds it under Binds in HostConfig' do
      cfg.volume('/host:/container')
      cfg.volume('/container1', '/host1:/container2')
      expect(cfg.options['Volumes']).to eql({
        '/container' => {},
        '/container1' => {},
        '/container2' => {}
      })
      expect(cfg.options['HostConfig']['Binds']).to match_array [
        '/host:/container', '/host1:/container2'
      ]
    end
  end

  describe '#volumes_from' do
    it 'returns itself' do
      expect(cfg.volumes_from('container')).to be_a described_class
    end

    it 'adds container info to VolumesFrom under HostConfig' do
      cfg.volumes_from('secure:ro')
      cfg.volumes_from('bob', 'sally')
      expect(cfg.options['HostConfig']['VolumesFrom']).to match_array [
        'secure:ro', 'bob', 'sally'
      ]
    end
  end

  describe '#workdir' do
    it 'returns itself' do
      expect(cfg.workdir('/dir')).to be_a described_class
    end

    [:w, :working_directory].each do |method|
      it "is accessible via ##{method}" do
        expect(cfg.method(method)).to eql cfg.method(:workdir)
      end
    end

    it 'updates WorkDir' do
      cfg.workdir('/dir')
      expect(cfg.options['WorkingDir']).to eql '/dir'
    end
  end

  describe '#split_proto_port' do
    subject { cfg.instance_eval { split_proto_port(arg) } }

    context 'when string is just a port' do
      it 'defaults to tcp' do
        expect(
          cfg.instance_eval{ split_proto_port('80') }
        ).to eql ['80', 'tcp']
      end
    end

    context 'when string includes port and protocol' do
      it 'parses both' do
        expect(
          cfg.instance_eval{ split_proto_port('500/udp') }
        ).to eql ['500', 'udp']
      end
    end
  end
end
