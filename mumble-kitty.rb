#!/usr/bin/env ruby
# frozen_string_literal: true

require "mumble-ruby"
require "eventmachine"
require "ruby-mpd"
require "thread"

STDOUT.sync = true
STDERR.sync = true

CONFIG = {
  general: {
    triggers: (ENV["TRIGGERS"] || "catnip,flausch,keks,minze").split(",")
  },
  mpd: {
    host: ENV["MPD_HOST"] || "localhost",
    port: (ENV["MPD_PORT"] || "6604").to_i,
    password: ENV["MPD_PASSWORD"],
    fifo: ENV["MPD_FIFO"] || "/var/lib/mpd/tmp/kitty.fifo"
  },
  mumble: {
    host: ENV["MUMBLE_HOST"] || "mumble.coding4.coffee",
    port: (ENV["MUMBLE_PORT"] || "64738").to_i,
    username: ENV["MUMBLE_USERNAME"] || "fluffy",
    channel: ENV["MUMBLE_CHANNEL"] || "katzenkörbchen"
  }
}.freeze

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
    @cli.player.stream_named_pipe(CONFIG[:mpd][:fifo])

    @mpd.connect
    @mpd.password(CONFIG[:mpd][:password]) if CONFIG[:mpd][:password]

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
              play_next
              sleep(60)
            end
          end
          if rand(2) > 0
            puts "#{Time.new.ctime}: sleep in #{CONFIG[:mumble][:channel]}"
            @cli.join_channel(CONFIG[:mumble][:channel])
            24.times do
              play_next
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
  end

  def play_next
    @mpd.play
  rescue MPD::Error => e
    puts "MPD error: '#{e.inspect}'"
    puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
    # retry after re-auth
    @mpd.password(CONFIG[:mpd][:password]) if CONFIG[:mpd][:password]
    retry
  end
end

EventMachine.run do
  client = MumbleMPD.new
  client.start
end
