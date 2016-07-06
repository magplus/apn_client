require 'spec_helper'

describe ApnClient::Message do
  before(:each) do
    @device_token = "7b7b8de5888bb742ba744a2a5c8e52c6481d1deeecc283e830533b7c6bf1d099"
    @other_device_token = "8c7b8de5888bb742ba744a2a5c8e52c6481d1deeecc283e830533b7c6bf5e699"
    @alert = "Hello, check out version 9.5 of our awesome app in the app store"
    @badge = 3
  end

  describe "#initialize" do
    it "cannot be created without a message_id" do
      expect{
        ApnClient::Message.new()
      }.to raise_error(/message_id/)
    end

    it "cannot be created without a token" do
      expect {
        ApnClient::Message.new(:message_id => 1)
      }.to raise_error(/device_token/)
    end

    it "can be created with a token and an alert" do
      message = create_message(:message_id => 1, :device_token => @device_token, :alert => @alert)
      expect(message.payload_hash).to eq({'aps' => {'alert' => @alert}})
    end

    it "can be created with a token and an alert and a badge" do
      message = create_message(:message_id => 1, :device_token => @device_token, :alert => @alert, :badge => @badge)
      expect(message.payload_hash).to eq({'aps' => {'alert' => @alert, 'badge' => @badge}})
    end

    it "can be created with a token and an alert and a badge and content-available" do
      message = create_message(
        :message_id => 1,
        :device_token => @device_token,
        :alert => @alert,
        :badge => @badge,
        :content_available => true)
      expect(message.payload_hash).to eq({'aps' => {'alert' => @alert, 'badge' => @badge, 'content-available' => 1}})
    end

    it "raises an exception if payload_size exceeds 256 bytes" do
      expect {
        too_long_alert = "A"*1000
        ApnClient::Message.new(:message_id => 1, :device_token => @device_token, :alert => too_long_alert)
      }.to raise_error(/payload/i)
    end
  end

  describe "attribute accessors" do
    it "works with symbol keys" do
      message = create_message(
        :message_id => 1,
        :device_token => @device_token,
        :alert => @alert,
        :badge => @badge,
        :content_available => true)
      expect(message.message_id).to be 1
      expect(message.badge).to eq @badge
      message.message_id = 3
      expect(message.message_id).to be 3
    end

    it "works with string keys too" do
      message = create_message(
        'message_id' => 1,
        'device_token' => @device_token,
        'alert' => @alert,
        'badge' => @badge,
        'content_available' => true)
      expect(message.message_id).to be 1
      expect(message.badge).to eq  @badge
      message.message_id = 3
      expect(message.message_id).to be 3
      expect(message.attributes).to eq({
        :message_id => 3,
        :device_token => @device_token,
        :alert => @alert,
        :badge => @badge,
        :content_available => true
      })
    end
  end

  describe "#==" do
    before(:each) do
      @message = create_message(:message_id => 3, :device_token => @device_token)
      @other_message = create_message(:message_id => 5, :device_token => @other_device_token)
    end

    it "returns false for nil" do
      expect(@message).not_to be_nil
    end

    it "returns false for an object that is not a Message" do
      expect(@message).not_to eq "foobar"
    end

    it "returns false for a Message with a different message_id" do
      expect(@message).not_to eq  @other_message
    end

    it "returns true for a Message with the same message_id" do
      @other_message.message_id = @message.message_id
      expect(@message).to eq @other_message
    end
  end

  describe "#to_hash" do
    it "returns a hash with the attributes of the message" do
      attributes = {
        :message_id => 1,
        :device_token => @device_token,
        :alert => @alert,
        :badge => @badge,
        :content_available => true
      }
      message = create_message(attributes)
      expect(message.to_hash).to eq attributes
    end
  end

  describe "#to_json" do
    it "converts the attributes hash to JSON" do
      attributes = {
        :message_id => 1,
        :device_token => @device_token,
        :alert => @alert,
        :badge => @badge,
        :content_available => true
      }
      message = create_message(attributes)
      expect(message.to_hash).to eq attributes
      expect(JSON.parse(message.to_json)).to eq({
        'message_id' => 1,
        'device_token' => @device_token,
        'alert' => @alert,
        'badge' => @badge,
        'content_available' => true
      })
    end
  end

  def create_message(attributes = {})
    message = ApnClient::Message.new(attributes)
    attributes.keys.each do |attribute|
      expect(message.send(attribute)).to eq attributes[attribute]
    end
    expect(message.payload_size).to be < 256
    expect(message.to_s).not_to be_nil
    message
  end
end
