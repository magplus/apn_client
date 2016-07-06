require 'spec_helper'

describe ApnClient::Delivery do
  before(:each) do
    @message1 = ApnClient::Message.new(
      :message_id => 1,
      :device_token => "7b7b8de5888bb742ba744a2a5c8e52c6481d1deeecc283e830533b7c6bf1d099",
      :alert => "New version of the app is out. Get it now in the app store!",
      :badge => 2
    )
    @message2 = ApnClient::Message.new(
      :message_id => 2,
      :device_token => "6a5g4de5888bb742ba744a2a5c8e52c6481d1deeecc283e830533b7c6bf1d044",
      :alert => "New version of the app is out. Get it now in the app store!",
      :badge => 1
    )
    @connection_config = {
        :host => 'gateway.push.apple.com',
        :port => 2195,
        :certificate => "certificate",
        :certificate_passphrase => ''
    }
  end

  describe "#initialize" do
    it "initializes counts and other attributes" do
      delivery = create_delivery([@message1, @message2], :connection_config => @connection_config)
      expect(delivery.connection_config).to eq @connection_config
    end
  end

  describe "#process!" do
    it "can deliver to all messages successfully and invoke on_write callback" do
      messages = [@message1, @message2]
      written_messages = []
      nil_selects = 0
      callbacks = {
          :on_write => lambda { |d, m| written_messages << m },
          :on_nil_select => lambda { |d| nil_selects += 1 }
        }
      delivery = create_delivery(messages.dup, :callbacks => callbacks, :connection_config => @connection_config)

      connection = mock('connection')
      connection.expects(:write).with(@message1)
      connection.expects(:write).with(@message2)
      connection.expects(:select).times(2).returns(nil)
      delivery.stubs(:connection).returns(connection)

      delivery.process!

      expect(delivery.failure_count).to be 0
      expect(delivery.success_count).to be 2
      expect(delivery.total_count).to be 2
      expect(written_messages).to eq messages
      expect(nil_selects).to be 2
    end

    it "fails a message if it fails more than 3 times" do
      messages = [@message1, @message2]
      written_messages = []
      exceptions = []
      failures = []
      read_exceptions = []
      callbacks = {
          :on_write => lambda { |d, m| written_messages << m },
          :on_exception => lambda { |d, e| exceptions << e },
          :on_failure => lambda { |d, m| failures << m },
          :on_read_exception => lambda { |d, e| read_exceptions << e }
        }
      delivery = create_delivery(messages.dup, :callbacks => callbacks, :connection_config => @connection_config)

      connection = mock('connection')
      connection.expects(:write).with(@message1).times(3).raises(RuntimeError)
      connection.expects(:write).with(@message2)
      connection.expects(:select).times(4).raises(RuntimeError)
      delivery.stubs(:connection).returns(connection)

      delivery.process!

      expect(delivery.failure_count).to be 1
      expect(delivery.success_count).to be 1
      expect(delivery.total_count).to be 2
      expect(written_messages).to eq [@message2]
      expect(exceptions.size).to eq 3
      expect(exceptions.first).to be_a(RuntimeError)
      expect(failures).to eq [@message1]
      expect(read_exceptions.size).to be 4
    end

    it "invokes on_connection_exception callback if there are OpenSSL problems" do
      exceptions = []
      callbacks = { :on_connection_exception => lambda { |d, e| exceptions << e } }
      delivery = create_delivery([@message1], :callbacks => callbacks, :connection_config => @connection_config)
      delivery.process!
      expect(exceptions).to be_one
    end

    it "invokes on_error callback if there are errors read" do
      messages = [@message1, @message2]
      written_messages = []
      exceptions = []
      failures = []
      read_exceptions = []
      errors = []
      callbacks = {
          :on_write => lambda { |d, m| written_messages << m },
          :on_exception => lambda { |d, e| exceptions << e },
          :on_failure => lambda { |d, m| failures << m },
          :on_read_exception => lambda { |d, e| read_exceptions << e },
          :on_error => lambda { |d, message_id, error_code| errors << [message_id, error_code] }
        }
      delivery = create_delivery(messages.dup, :callbacks => callbacks, :connection_config => @connection_config)

      connection = mock('connection')
      connection.expects(:write).with(@message1)
      connection.expects(:write).with(@message2)
      selects = sequence('selects')
      connection.expects(:select).returns("something").in_sequence(selects)
      connection.expects(:select).returns(nil).in_sequence(selects)
      connection.expects(:read).returns("something")
      delivery.stubs(:connection).returns(connection)

      delivery.process!

      expect(delivery.failure_count).to be 1
      expect(delivery.success_count).to be 1
      expect(delivery.total_count).to be 2
      expect(written_messages).to eq [@message1, @message2]
      expect(exceptions.size).to be 0
      expect(failures.size).to be 0
      expect(errors).to eq [[1752458605, 111]]
    end
  end

  def create_delivery(messages, options = {})
    delivery = ApnClient::Delivery.new(messages, options)
    expect(delivery.messages).to eq messages
    expect(delivery.callbacks).to eq options[:callbacks]
    expect(delivery.exception_count).to be 0
    expect(delivery.success_count).to be 0
    expect(delivery.failure_count).to be  0
    expect(delivery.consecutive_failure_count).to be 0
    expect(delivery.started_at).to be_nil
    expect(delivery.finished_at).to be_nil
    expect(delivery.elapsed).to be 0
    expect(delivery.consecutive_failure_limit).to be 10
    expect(delivery.exception_limit).to be 3
    expect(delivery.sleep_on_exception).to be 1
    delivery
  end
end
