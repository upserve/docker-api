# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

SingleCov.covered! uncovered: 5

describe Docker::Event do
  let(:api_response) do
    {
      'Action' => 'start',
      'Actor' => {
        'Attributes' => {
          'image' => 'tianon/true',
          'name' => 'true-dat'
        },
        'ID' => 'bb2c783a32330b726f18d1eb44d80c899ef45771b4f939326e0fefcfc7e05db8'
      },
      'Type' => 'container',
      'from' => 'tianon/true',
      'id' => 'bb2c783a32330b726f18d1eb44d80c899ef45771b4f939326e0fefcfc7e05db8',
      'scope' => 'local',
      'status' => 'start',
      'time' => 1461083270,
      'timeNano' => 1461083270652069004
    }
  end

  describe "#to_s" do
    context 'with an old event' do
      let(:event) do
        described_class.new(
          status: status,
          id: id,
          from: from,
          time: time
        )
      end

      let(:status) { "start" }
      let(:id) { "398c9f77b5d2" }
      let(:from) { "debian:stable" }
      let(:time) { 1381956164 }

      let(:expected_string) {
        "Docker::Event { #{time} #{status} #{id} (from=#{from}) }"
      }

      it "equals the expected string" do
        expect(event.to_s).to eq(expected_string)
      end
    end

    context 'with a new event' do
      let(:event) { described_class.new(api_response) }

      let(:expected_string) do
        'Docker::Event { 1461083270652069004 container start '\
        'bb2c783a32330b726f18d1eb44d80c899ef45771b4f939326e0fefcfc7e05db8 '\
        '(image=tianon/true, name=true-dat) }'
      end

      it 'equals the expected string' do
        expect(event.to_s).to eq(expected_string)
      end
    end
  end

  describe ".stream" do
    it 'receives at least 4 events' do
      events = 0

      stream_thread = Thread.new do
        Docker::Event.stream do |event|
          puts "#{event}"
          events += 1

          break if events >= 4
        end
      end

      container = Docker::Image.create('fromImage' => 'debian:stable')
        .run('bash')
        .tap(&:wait)

      stream_thread.join(10) || stream_thread.kill

      expect(events).to be >= 4

      container.remove
    end

    context 'with timeouts' do
      # @see https://github.com/upserve/docker-api/issues/584

      it 'does not (seem to) time out by default' do
        # @note Excon passes timeout-related arguments directly to IO.select, which in turn makes a system call,
        #   so it's not possible to mock this (e.g. w/Timecop).
        skip_slow_test
        expect { Timeout.timeout(65) { stream_events_with_timeout } }
          .to raise_error Timeout::Error
      end

      it 'times out immediately if read_timeout < Timeout.timeout' do
        expect { Timeout.timeout(1) { stream_events_with_timeout(0) } }
          .to raise_error Docker::Error::TimeoutError
      end

      it 'times out after timeout(1) if read_timeout=2' do
        expect { Timeout.timeout(1) { stream_events_with_timeout(2) } }
          .to raise_error Timeout::Error
      end

      private

      def stream_events_with_timeout(read_timeout = [])
        opts = {
          # Filter to avoid unexpected Docker events interfering with timeout behavior
          query: { filters: { container: [SecureRandom.uuid] }.to_json },
          # Use [] to differentiate between explicit nil and not providing an arg (falling back to the default)
          read_timeout: read_timeout,
        }.reject { |_, v| v.empty? rescue false }

        Docker::Event.stream(opts) do |event|
          raise "Unexpected event interfered with timeout test: #{event}"
        end
      end
    end
  end

  describe ".since" do
    let(:time) { Time.now.to_i + 1 }

    it 'receives at least 4 events' do
      skip('Not supported on podman') if ::Docker.podman?
      events = 0

      stream_thread = Thread.new do
        Docker::Event.since(time) do |event|
          puts "#{event}"
          events += 1

          break if events >= 4
        end
      end

      container = Docker::Image.create('fromImage' => 'debian:stable')
        .run('bash')
        .tap(&:wait)

      stream_thread.join(10) || stream_thread.kill

      expect(events).to be >= 4

      container.remove
    end
  end

  describe ".new_event" do
    context 'with an old api response' do
      let(:event) { Docker::Event.new_event(response_body, nil, nil) }
      let(:status) { "start" }
      let(:id) { "398c9f77b5d2" }
      let(:from) { "debian:stable" }
      let(:time) { 1381956164 }
      let(:response_body) {
        "{\"status\":\"#{status}\",\"id\":\"#{id}\""\
        ",\"from\":\"#{from}\",\"time\":#{time}}"
      }

      it "returns a Docker::Event" do
        expect(event).to be_kind_of(Docker::Event)
        expect(event.status).to eq(status)
        expect(event.id).to eq(id)
        expect(event.from).to eq(from)
        expect(event.time).to eq(time)
      end
    end

    context 'with a new api response' do
      let(:event) do
        Docker::Event.new_event(
          MultiJson.dump(api_response),
          nil,
          nil
        )
      end

      it 'returns a Docker::Event' do
        expect(event).to be_kind_of(Docker::Event)
        expect(event.type).to eq('container')
        expect(event.action).to eq('start')
        expect(
          event.actor.id
        ).to eq('bb2c783a32330b726f18d1eb44d80c899ef45771b4f939326e0fefcfc7e05db8')
        expect(event.actor.attributes).to eq('image' => 'tianon/true', 'name' => 'true-dat')
        expect(event.scope).to eq('local')
        expect(event.time).to eq 1461083270
        expect(event.time_nano).to eq 1461083270652069004
      end
    end
  end
end
