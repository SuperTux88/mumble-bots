#!/usr/bin/env ruby
 
require "mumble-ruby"
require "eventmachine"
require "ruby-mpd"
 
class MumbleMPD
 
	def initialize
		@mpd = MPD.new "localhost", 6600, callbacks: true
 
		@cli = Mumble::Client.new("mumble.coding4coffee.org", "64738", "music-bot", "")
	end
 
	def start
		@cli.connect
		sleep(1)
		@cli.player.stream_named_pipe('/var/lib/mpd/tmp/mpd.fifo')

		add_mpd_callbacks

		@mpd.connect
 
		if @mpd.stopped?
			@mpd.play
		end
	end
 
	def add_mpd_callbacks
		@mpd.on :playlistlength do |length|
			if length < 2
				playlist = MPD::Playlist.new @mpd, "playlist"
				playlist.load
			end
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
