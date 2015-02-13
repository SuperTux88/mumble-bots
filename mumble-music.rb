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
 
		@mpd = MPD.new
 
		@cli = Mumble::Client.new("mumble.coding4coffee.org", "64738", "music-bot", "")
 
		@mpd.register_callback( self.method('song_cb'), MPD::CURRENT_SONG_CALLBACK )
	end
 
	def start
		@cli.connect
		sleep(1)
		#@cli.join_channel("weltraum")
		#sleep(1)
		@cli.stream_raw_audio('/var/lib/mpd/tmp/mpd.fifo')
 
		@mpd.connect true
 
		if @mpd.stopped?
			@mpd.play
		end
 
		@cli.on_udp_tunnel do |udp|
            		@lastaudio = Time.now
        	end				
        	
		begin
			@lastaudio = Time.now
			t = Thread.new do
				# This implements ducking Bot when others speak
				while (true==true)
					sleep 0.02
					if ((Time.now - @ lastaudio) < 0.1) then
						@cli.player.volume = 40
					else
						@cli.player.volume = 100
					end
				end
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
				@cli.text_channel(@cli.current_channel, "MPD: #{current.artist} - #{current.title} (#{current.album})")
			end
		end
	end
end
 
client = MumbleMPD.new
client.start
