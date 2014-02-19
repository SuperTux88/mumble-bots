#!/usr/bin/env ruby
# encoding: utf-8
 
require "mumble-ruby"
require 'rubygems'
require 'librmpd'
require 'thread'
 
class MumbleMPD
 
	def initialize 
		@mpd = MPD.new("localhost", 6604)
 
		@cli = Mumble::Client.new("mumble.coding4coffee.org", "64738", "fluffy", "")
	end
 
	def start
		@cli.connect
		sleep(1)
		@cli.join_channel("katzenkörbchen")
		sleep(1)
		@cli.stream_raw_audio("/var/lib/mpd/tmp/kitty.fifo")
 
		@mpd.connect

		begin
			running = true
			Thread.new do
				sleep(2)
				while running
					12.times do
						channels = @cli.channels.values
						newChannel = channels[rand(channels.length)]
						puts Time.new.ctime + ": " + newChannel.name
						@cli.join_channel(newChannel)
						5.times do
							@mpd.play()
							sleep(60)
						end
					end
					if rand(2) > 0
						puts Time.new.ctime + ": sleep in katzenkörbchen"
						@cli.join_channel("katzenkörbchen")
						24.times do
							@mpd.play()
							sleep(300)
						end
					else
						puts Time.new.ctime + ": sleep"
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
