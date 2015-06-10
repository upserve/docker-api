class Docker::MessagesStack

  attr_accessor :messages

  # Initialize stack with optional size
  #
  # @param size [Integer]
  def initialize(size = -1)
    @messages = []
    @size = size
  end

  # Append messages to stack
  #
  # @param messages [Docker::Messages]
  def append(messages)
    messages.all_messages.each do |msg|
      @messages << msg
      @messages.shift if @size > -1 && @messages.size > @size
    end
  end
end
