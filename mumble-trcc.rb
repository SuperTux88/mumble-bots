#!/usr/bin/env ruby
 
require "mumble-ruby"
require 'rubygems'
require 'librmpd'
require 'thread'
 
class MumbleMPD
 
	def initialize
		@sv_art
		@sv_alb
		@sv_tit
 
		@mpd = MPD.new 'localhost', 6601
 
		@cli = Mumble::Client.new("mumble.coding4coffee.org", "64738", "radio-bot", "")
 
		#@mpd.register_callback( self.method('song_cb'), MPD::CURRENT_SONG_CALLBACK )
	end
 
	def start
		@cli.connect
		sleep(1)
		#@cli.join_channel("TheRadio.CC")
		#sleep(1)
		@cli.stream_raw_audio('/var/lib/mpd/tmp/trcc.fifo')
 
		@mpd.connect true
 
		begin
			t = Thread.new do
				gets
			end
 
			t.join
		rescue Interrupt => e
		end
	end
 
	def song_cb( current )
		if not current.nil?
			if not @sv_art == current.artist && @sv_alb == current.album && @sv_tit == current.title
				@sv_art = current.artist
				@sv_alb = current.album
				@sv_tit = current.title
				@cli.text_channel(@cli.current_channel, "#{current.artist} - #{current.title} (#{current.album})")
			end
		end
	end
end
 
client = MumbleMPD.new
client.start
