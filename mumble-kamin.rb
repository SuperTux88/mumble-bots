#!/usr/bin/env ruby
# frozen_string_literal: true

require "mumble-ruby"
require "eventmachine"

CONFIG = {
  mpd: {
    fifo: ENV["MPD_FIFO"] || "/var/lib/mpd/tmp/kamin.fifo",
  },
  mumble: {
    host: ENV["MUMBLE_HOST"] || "mumble.coding4.coffee",
    port: (ENV["MUMBLE_PORT"] || "64738").to_i,
    username: ENV["MUMBLE_USERNAME"] || "kamin-bot",
  }
}.freeze

class MumbleMPD
  def initialize
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
    #@cli.join_channel("kaminzimmer")
    #sleep(1)
    @cli.player.stream_named_pipe(CONFIG[:mpd][:fifo])
  end
end

EventMachine.run do
  client = MumbleMPD.new
  client.start
end
