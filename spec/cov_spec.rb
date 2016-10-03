require 'spec_helper'

SingleCov.not_covered!

describe "Coverage" do
  it "has coverage for all tests" do
    SingleCov.assert_used
  end

  it "has tests for all files" do
    SingleCov.assert_tested untested: %w[
      lib/docker/base.rb
      lib/docker/error.rb
      lib/docker/messages_stack.rb
      lib/docker/rake_task.rb
      lib/docker/version.rb
      lib/docker-api.rb
      lib/excon/middlewares/hijack.rb
    ]
  end
end
