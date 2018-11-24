#!/usr/bin/env ruby

require "mumble-ruby"
require "restclient"
require "eventmachine"
require "json"
require "twitter-text"

CONFIG = {
  mumble: {
    host: ENV["MUMBLE_HOST"] || "mumble.coding4.coffee",
    port: (ENV["MUMBLE_PORT"] || "64738").to_i,
    username: ENV["MUMBLE_USERNAME"] || "telegram-bot",
    channel: ENV["MUMBLE_CHANNEL"] || "weltraum"
  },
  telegram: {
    bot_token: ENV["TELEGRAM_BOT_TOKEN"] || "",
    chat_id: (ENV["TELEGRAM_CHAT_ID"] || "").to_i
  }
}

class MumbleMPD
  def initialize
    @cli = Mumble::Client.new(
      CONFIG[:mumble][:host],
      CONFIG[:mumble][:port],
      CONFIG[:mumble][:username],
      ""
    )
    @update_options = {offset: 0, timeout: 60}
    @users = {}
  end

  def start
    @cli.on_user_state do |msg|
      user = @users[msg.session] ||= {name: msg.name}

      if @cli.me && @cli.me.session != msg.session
        if msg.channel_id == @cli.me.channel_id
          send_join_leave_message("<b>#{@users[msg.session][:name]}</b> joined #{@cli.me.current_channel.name}")
        elsif user[:channel_id] == @cli.me.channel_id && msg.channel_id && user[:channel_id] != msg.channel_id
          send_join_leave_message("<b>#{@users[msg.session][:name]}</b> left #{@cli.me.current_channel.name}")
        end
      end

      @users[msg.session][:channel_id] = msg.channel_id if msg.channel_id
    end

    @cli.on_user_remove do |msg|
      user = @users.delete(msg.session)
      send_join_leave_message("<b>#{user[:name]}</b> disconnected") if user[:channel_id] == @cli.me.channel_id
    end

    @cli.connect
    sleep(1)
    @cli.join_channel(CONFIG[:mumble][:channel])

    @cli.on_text_message do |msg|
      if msg.channel_id.include?(@cli.me.channel_id)
        send_to_telegram("<b>#{@cli.users[msg.actor].name}:</b> #{msg.message}") unless msg.message.include?("<img ")
      end
    end

    fetch_updates_from_telegram while true
  end

  private

  def telegram_url
    @telegram_url ||= "https://api.telegram.org/bot#{CONFIG[:telegram][:bot_token]}"
  end

  def send_join_leave_message(text)
    send_to_telegram(text, {disable_notification: true})
  end

  def send_to_telegram(text, additional_params={})
      params = {
        chat_id: CONFIG[:telegram][:chat_id],
        text: text,
        parse_mode: "HTML"
      }.merge(additional_params)
      puts "Sending to Telegram: #{params.inspect}"
      RestClient.post("#{telegram_url}/sendMessage", params, format: :json)
      puts "... done."
    rescue SocketError, RestClient::Exception => e
      puts "... Telegram send error: '#{e.inspect}'"
  end

  def fetch_updates_from_telegram
    response = JSON.parse(RestClient.post("#{telegram_url}/getUpdates", @update_options, format: :json))
    return unless response["ok"]

    response["result"].each do |data|
      @update_options[:offset] = data["update_id"].next
      puts "Received message: #{data["message"]}"
      next unless data["message"]["chat"]["id"] == CONFIG[:telegram][:chat_id] && data["message"]["text"]
      text = Twitter::TwitterText::Autolink.auto_link_urls(data["message"]["text"], suppress_no_follow: true)
      @cli.text_channel(@cli.me.current_channel, "<b>#{telegram_name(data["message"]["from"])}</b>: #{text}")
    end
  end

  def telegram_name(from)
    "#{from["first_name"]} #{from["last_name"]}".strip
  end
end

EventMachine.run do
  client = MumbleMPD.new
  client.start
end
