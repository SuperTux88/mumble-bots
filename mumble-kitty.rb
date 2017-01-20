#!/usr/bin/env ruby
# encoding: utf-8

require "librmpd"
require "mumble-ruby"
require "rubygems"
require "thread"

CONFIG = {
  general: {
    triggers: (ENV["KITTY_TRIGGERS"] || "catnip,flausch,keks,minze").split(",")
  },
  mpd: {
    host: ENV["KITTY_MPD_HOST"] || "localhost",
    port: (ENV["KITTY_MPD_PORT"] || "6604").to_i,
    fifo: ENV["KITTY_MPD_FIFO"] || "/var/lib/mpd/tmp/kitty.fifo"
  },
  mumble: {
    host: ENV["KITTY_MUMBLE_HOST"] || "mumble.coding4coffee.org",
    port: (ENV["KITTY_MUMBLE_PORT"] || "64738").to_i,
    username: ENV["KITTY_MUMBLE_USERNAME"] || "fluffy",
    channel: ENV["KITTY_MUMBLE_CHANNEL"] || "katzenkörbchen"
  }
}

class MumbleMPD

  def initialize
    @mpd = MPD.new(
      CONFIG[:mpd][:host],
      CONFIG[:mpd][:port]
    )

    @cli = Mumble::Client.new(
      CONFIG[:mumble][:host],
      CONFIG[:mumble][:port],
      CONFIG[:mumble][:username],
      ""
    )
  end

  def start
    @cli.connect
    sleep(1)
    @cli.join_channel(CONFIG[:mumble][:channel])
    sleep(1)
    if @cli.player and @cli.player.respond_to? :stream_named_pipe
      @cli.player.stream_named_pipe(CONFIG[:mpd][:fifo])
    else
      @cli.stream_raw_audio(CONFIG[:mpd][:fifo])
    end

    @mpd.connect

    @cli.on_text_message do |msg|
      text = msg.message.downcase
      if CONFIG[:general][:triggers].any? {|trigger| text.include?(trigger)}
        puts "#{Time.new.ctime}: Received trigger message, following sender!"
        @cli.join_channel(@cli.users[msg.actor].channel_id)
      end
    end

    begin
      running = true
      Thread.new do
        sleep(2)
        while running
          12.times do
            channels = @cli.channels.values
            newChannel = channels[rand(channels.length)]
            puts "#{Time.new.ctime}: #{newChannel.name}"
            @cli.join_channel(newChannel)
            5.times do
              @mpd.play()
              sleep(60)
            end
          end
          if rand(2) > 0
            puts "#{Time.new.ctime}: sleep in #{CONFIG[:mumble][:channel]}"
            @cli.join_channel(CONFIG[:mumble][:channel])
            24.times do
              @mpd.play()
              sleep(300)
            end
          else
            puts "#{Time.new.ctime}: sleep"
            sleep(7200)
          end
        end
      end
    rescue Interrupt => e
    end

    begin
      t = Thread.new do
        gets
      end

      t.join
    rescue Interrupt => e
    end
  end
end

client = MumbleMPD.new
client.start
