#!/usr/bin/env ruby
 
require "mumble-ruby"
require 'rubygems'
require 'librmpd'
require 'thread'
 
class MumbleMPD
 
	def initialize
		@mpd = MPD.new("localhost", 6602)
 
		@cli = Mumble::Client.new("mumble.coding4coffee.org", "64738", "welcome-bot", "")
	end
 
	def start
		@cli.connect
		sleep(1)

		@cli.on_user_state do |msg|
			begin
				time = Time.new
				puts time.inspect + ": callback called"
				puts "new user channel: " + msg.channel_id.to_s
				if msg.channel_id == @cli.current_channel.channel_id
					puts "mpd play 0"
					@mpd.play(0)
				end
			rescue
				puts $!, $@
			end
		end

		@cli.join_channel("Willkommensraum")
		sleep(1)
		@cli.stream_raw_audio('/var/lib/mpd/tmp/welcome.fifo')
 
		@mpd.connect true
 
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
