#!/usr/bin/env ruby

require "mumble-ruby"
require "restclient"
require "eventmachine"
require "json"

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
  end

  def start
    @cli.connect
    sleep(1)
    @cli.join_channel(CONFIG[:mumble][:channel])

    @cli.on_text_message do |msg|
      if msg.channel_id.include?(@cli.me.channel_id)
        params = {
          chat_id: CONFIG[:telegram][:chat_id],
          text: "<b>#{@cli.users[msg.actor].name}:</b> #{msg.message}",
          parse_mode: "HTML"
        }
        send_to_telegram(params)
      end
    end

    fetch_updates_from_telegram while true
  end

  private

  def telegram_url
    @telegram_url ||= "https://api.telegram.org/bot#{CONFIG[:telegram][:bot_token]}"
  end

  def send_to_telegram(params)
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
      next unless data["message"]["chat"]["id"] == CONFIG[:telegram][:chat_id]
      @cli.text_channel(@cli.me.current_channel, "<b>#{telegram_name(data["message"]["from"])}</b>: #{data["message"]["text"]}") if data["message"]["text"]
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
