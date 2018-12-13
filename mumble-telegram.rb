#!/usr/bin/env ruby

require "mumble-ruby"
require "restclient"
require "open-uri"
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

class MumbleTelegram
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

  def log(line)
    puts "[#{Time.now}] #{line}"
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
      if !msg.channel_id || msg.channel_id.include?(@cli.me.channel_id)
        send_to_telegram("<b>#{@cli.users[msg.actor].name}:</b> #{msg.message}") unless msg.message.include?("<img ")
      end
    end

    fetch_updates_from_telegram while true
  end

  private

  def telegram_api(method, params)
    RestClient.post("https://api.telegram.org/bot#{CONFIG[:telegram][:bot_token]}/#{method}", params, format: :json)
  end

  def telegram_download_file(path)
    download = open("https://api.telegram.org/file/bot#{CONFIG[:telegram][:bot_token]}/#{path}")
    "/tmp/telegram-#{path.gsub("/", "-")}".tap do |target_filename|
      IO.copy_stream(download, target_filename)
    end
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
    log "Sending to Telegram: #{params.inspect}"
    telegram_api("sendMessage", params)
    log "... done."
  rescue SocketError, RestClient::Exception => e
    log "... Telegram send error: '#{e.inspect}'"
  end

  def fetch_updates_from_telegram
    response = JSON.parse(telegram_api("getUpdates", @update_options))
    return unless response["ok"]

    response["result"].each do |data|
      @update_options[:offset] = data["update_id"].next
      message = data["message"]
      puts "Received message: #{message}"

      send_list(message["chat"]["id"]) if message["text"] && message["text"].start_with?("/list")

      next unless message["chat"]["id"] == CONFIG[:telegram][:chat_id]

      if message["text"] && !message["text"].start_with?("/")
        text = Twitter::TwitterText::Autolink.auto_link_urls(message["text"], suppress_no_follow: true)
        @cli.text_channel(@cli.me.current_channel, "<b>#{telegram_name(message["from"])}</b>: #{text}")
      elsif message["voice"]
        play_voice(message["voice"])
      end
    end
  end

  def telegram_name(from)
    "#{from["first_name"]} #{from["last_name"]}".strip
  end

  def send_list(chat_id)
    users = @users.values.select {|user| user[:channel_id] == @cli.me.channel_id && user[:name] != CONFIG[:mumble][:username]}
    if users.any?
      text = "Users in channel <b>#{@cli.me.current_channel.name}</b>:\n- #{users.map {|user| user[:name]}.join("\n- ")}"
    else
      text = "Channel <b>#{@cli.me.current_channel.name}</b> is empty!"
    end

    send_to_telegram(text, {chat_id: chat_id})
  end

  def play_voice(voice)
    response = JSON.parse(telegram_api("getFile", {file_id: voice["file_id"]}))
    return unless response["ok"]

    downloaded_file = telegram_download_file(response["result"]["file_path"])

    return unless system("ffmpeg -i #{downloaded_file} -ac 1 -ar 48000 -acodec pcm_s16le -y /tmp/telegram-voice.wav")
    File.delete(downloaded_file) if File.exist?(downloaded_file)

    @cli.player.play_file("/tmp/telegram-voice.wav")
    sleep(voice["duration"] + 1)
  end
end

EventMachine.run do
  client = MumbleTelegram.new
  client.start
end
