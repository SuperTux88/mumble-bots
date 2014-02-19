#!/usr/bin/env ruby
 
require "mumble-ruby"
require 'rubygems'
require 'thread'
 
class MumbleMPD
 
	def initialize
		@cli = Mumble::Client.new("mumble.coding4coffee.org", "64738", "kamin-bot", "")
	end
 
	def start
		@cli.connect
		sleep(1)
		#@cli.join_channel("kaminzimmer")
		#sleep(1)
		@cli.stream_raw_audio('/var/lib/mpd/tmp/kamin.fifo')
 
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
