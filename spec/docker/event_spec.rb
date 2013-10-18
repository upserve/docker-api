require 'spec_helper'

describe Docker::Event do
  describe "#to_s" do
    subject { described_class.new(status, id, from, time) }

    let(:status) { "start" }
    let(:id) { "398c9f77b5d2" }
    let(:from) { "base:latest" }
    let(:time) { 1381956164 }

    let(:expected_string) {
      "Docker::Event { :status => #{status}, :id => #{id}, "\
      ":from => #{from}, :time => #{time.to_s} }"
    }

    it "equals the expected string" do
      expect(subject.to_s).to eq(expected_string)
    end
  end

  describe ".stream" do
    it 'receives three events', :vcr do
      Docker::Event.should_receive(:yield_event).exactly(3).times.and_call_original

      Docker::Event.stream do |event|
        if event.status == 'die'
          break
        end
      end
    end
  end

  describe ".since" do
  end

  describe ".yield_event" do
    let(:status) { "start" }
    let(:id) { "398c9f77b5d2" }
    let(:from) { "base:latest" }
    let(:time) { 1381956164 }
    let(:response_body) {
      "{\"status\":\"#{status}\",\"id\":\"#{id}\",\"from\":\"#{from}\",\"time\":#{time}}"
    }

    it "yields a Docker::Event" do
      expect { |event|
        Docker::Event.yield_event(response_body, nil, nil, &event)
      }.to yield_with_args(Docker::Event)
    end
  end
end
