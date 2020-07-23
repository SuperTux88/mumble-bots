#!/usr/bin/env ruby
# frozen_string_literal: true

require "mumble-ruby"
require "eventmachine"
require "ruby-mpd"

CONFIG = {
  mpd: {
    host: ENV["MPD_HOST"] || "localhost",
    port: (ENV["MPD_PORT"] || "6600").to_i,
    password: ENV["MPD_PASSWORD"],
    fifo: ENV["MPD_FIFO"] || "/var/lib/mpd/tmp/music.fifo",
    playlist: ENV["MPD_PLAYLIST"] || "playlist"
  },
  mumble: {
    host: ENV["MUMBLE_HOST"] || "mumble.coding4.coffee",
    port: (ENV["MUMBLE_PORT"] || "64738").to_i,
    username: ENV["MUMBLE_USERNAME"] || "music-bot",
  }
}.freeze

class MumbleMPD
  def initialize  
    @mpd = MPD.new(
      CONFIG[:mpd][:host],
      CONFIG[:mpd][:port],
      callbacks: true
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
    @cli.player.stream_named_pipe(CONFIG[:mpd][:fifo])

    add_mpd_callbacks

    @mpd.connect
    @mpd.password(CONFIG[:mpd][:password]) if CONFIG[:mpd][:password]

    @mpd.play if @mpd.stopped?
  end

  def add_mpd_callbacks
    @mpd.on :playlistlength do |length|
      MPD::Playlist.new(@mpd, CONFIG[:mpd][:playlist]).load if length < 2
    end

    @mpd.on :song do |song|
      if !song.nil? && !(@sv_art == song.artist && @sv_alb == song.album && @sv_tit == song.title)
        @sv_art = song.artist
        @sv_alb = song.album
        @sv_tit = song.title
        @cli.text_channel(@cli.me.current_channel, "MPD: #{"#{song.artist} - " if song.artist}#{song.title}#{" (#{song.album})" if song.album}")
      end
    end
  end
end

EventMachine.run do
  client = MumbleMPD.new
  client.start
end
