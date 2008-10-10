#!/usr/bin/env ruby

# Renamer2.rb
# Version 2.3
# Copyright 2007 Kevin Adler
# License: GPL v2
# Changelog

# Version 2.3.3
# Added support for 3 digit episode numbers to support all of Colbert Report eps
# This does not work if the name is a straight number ala Charmed 804.avi because that
# would cause too much guesstimation on my part (is it a 2 digit season and 2 digit episode
# or 1 digit season and 3 digit episode?)

# Version 2.3.2
# Fixed it so that it actually reads and uses the third parameter in the shows.txt, not sure what happened there
# Fixed the url.chomp! being in the wrong place so that it sometimes tries to call on nil, causing Exception
#  (How many times have I fixed that already and I keep losing the changes?)

# Version 2.3.1
# Fixed bug where the renamer assumes that the extension is 3 characters

# Version 2.3
# Added ability to individually retrieve episode and title from a filename
# for instance from: incite-chappelles.show.s01.e01.proper.dvdrip.xvid

# Version 2.2.5
# Fixed bug with wrong variable name @shows_files_exists -> @show_exists

# Version 2.2.4

# Fixed bug with program exiting after episode not found on epguides.
# Fixed bug with not being able to match show name, now we remove the extention before trying to match,
#	I dont exactly know how it was even matching before.

# Version 2.2.3

# Fixed some errors with files named show.s#e##.avi

# Version 2.2.2

# Removed some debug output

# Version 2.2.1

#  shows.txt should work just fine now on windows and linux!

# Version 2.2.1a
# Test to see if shows.txt will be found on windows. Apparently you can not use the shell variable like I was using it,
# if you are in the C directory, it will point to C:\Documents..\Username\ because the shell variable actually points to
# \Documents..\Username and the C: gets prepended to it because you are browsing the C: directory. So what we do is
# open up cmd.exe, echo the variable and then grab the output and use a full path: C:(output from cmd.exe). Since I don't
# have windows available for testing at this time, it is not 100% guaranteed to work.

# Version 2.2
# -No more rename.txt! This functionality is now built in to shows.txt, first is the input title <tab> epguides name <tab> renamed name

# Version 2.1.2
# -Fixed rename.txt not being found on windows. Since windows is dumb and %Homepath% does not include the drive
#  letter, we include "C:" before %HOMEPATH%

# Version 2.1.1
# -Fixed hack for "The 4400" remember, !show.downcase() == "the" is not the same as show.downcase() != "the"
# -Also fixed problems with show.SSEE.avi or show.SEE.avi filters, remember ruby array slices are inclusive on
#	first number, but exclusive on last number UNLESS last number is end of array => switched to ranges instead to avoid errors again

# Version 2.1

# New and improved! Now with Versioning!

# renames files such as
# Gilmore Girls s01e13 - Concert Interruptus.avi
# Farscape [1x01] - Premiere.avi
# Arrested.Development.3x07.avi
# Mork.and.Mindy.S01E03.avi
# Lost.S3E21.avi
# Gilmore Girls - 503 - Written in the Stars.avi
#
# to Show Name-Season Number without Trailing 0-Episode Number with Trailing 0-Episode Title.extension
require 'net/http'

class Renamer

def initialize

	#check if windows or linux
	if RUBY_PLATFORM['linux']
		@shows = '/home/zeke/shows.txt'
	else
		output = Array.new
		IO.popen( 'cmd.exe' , "r+" ) do  | shell |
			shell.puts "echo %HOMEPATH%"
			shell.close_write()
			shell.each do |l|
				output << l.chomp
			end	
		end
		path = nil
		output.each_index do |i|
			if output[i].match('echo %HOMEPATH%')
				path = output[i+1]
				break
			end
		end
		if path
			@shows = 'C:' + path + '\\shows.txt'
		end
	end
	
	splits = [ ' ', '.' ]
	@video_list = Dir['*.{avi,wmv,divx,mpg,mpeg,xvid,mp4,mkv}']
	@videos = Hash.new
	@video_list.each do | video|
		@videos[video] = false
	end
	@show_exists = true
	splits.each do |char|
		movies = @videos.dup
		movies.each do |movie, warned|
			pieces = movie.delete("[]").gsub(" - ", " ").gsub( /\([-\w]+\)/, '' ).match(/[.][a-zA-Z]+$/).pre_match.split(char)
			if pieces.length > 1 
				@file = movie
				@show = nil
				@season = nil
				@episode = nil
				@extension = movie.split('.')[-1]
				
				if !parse_showname(pieces)
					if  !warned # only display if on the last pass
						print "I could not match " + movie + " to a naming pattern I can interpret\n"
						@videos[movie] = true
					end
				else
					rename_status = rename()
					if !rename_status #page exists, but episodes not listed
						print "Epguides does not have " + @show + " season: " + @season + " episode: " + @episode + " in it's guides.\n"
					elsif rename_status == "404"
						url = nil
						if @show_exists && File.exists?(@shows)
							IO::readlines(@shows).each do |line|
								if line.downcase.match(@show.downcase)
									aliases = line.split("\t")
									aliases.each_index do |i|
										if i != 0 && !aliases[i].empty?
											url = aliases[i]
											url.chomp!
											break
										end # if i != 0
									end # aliases.each
									if(aliases[-1] != url) then @show = aliases[-1] end
								end # line.match
							end # IO::readlines
						else
							@show_exists = false
							print @shows + " does not exist, will not be able to locate this show without help\n"
							@videos.delete(@file)
						end # if @show exists
						if !url
							print "Please add an alias of the epguide.com show url for " + @show + " to the shows file\n"
							@videos.delete(@file)
						else
							rename(url)
						end # if !url						
					end # if !rename_status
				end # if !parse_showname(pieces)
			end # if pieces.length < 2
		end # movies.each do |movie|
	end # splits.each do |char|
end # def initialize

def rename(url=nil)
	if !url then url = show_to_url() end
	
	page = Net::HTTP.new('www.epguides.com', nil)
	begin
		resp, data = page.get('/' + url  + '/')
	rescue
		print "Error loading www.epguides.com/" + url + "/\n"
	end
		
	
	if resp.code == "404"
		return resp.code
	else
		lines =  data.split(/(\n|\r)/)
		lines.each do |line|
		
			ep = "#{@episode}"
			if(@episode.length < 2) then ep = " " + ep end
	
			match = @season + "-" + ep
			if line.match(match)
				if line.match("<li>")
					name = line[35,line.length]
					name.delete!("\r")
				else
					name = line.match(/[>][0-9a-zA-Z\-!: ',?`~#¡\/\$%^&*()".+=-_]+/)[0]
					name = name[1,name.length]
				end # if line.match("<li>")
				if @show_exists && File::exists?(@shows)
					IO::readlines(@shows).each do |line|
						if line.match(@show.downcase)
							aliases = line.split("\t")
							if @show.downcase == aliases[0]
								@show = aliases[aliases.length-1]
							end
						end
					end
					@show.chomp!	
				else
					@show_exists = false
					print @shows + " does not exist, will not beable to do custom renaming\n"
				end
	
				if @episode.length < 2 then @episode = "0" + @episode end
				filename = @show + " - " + @season + " - " + @episode + " - " + name + "." + @extension
# 				filename = @show + "-" + @season + "-" + @episode + "-" + name + "." + @extension
				filename.gsub!(":", "-")
				filename.gsub!("/", "-")
				filename.delete!("?\\/<>\"")
	
				if !File::exist?(filename)
					File::rename(@file, filename)
					@videos.delete(@file)
				else
					print "Can't rename " + @file + "!\n"
					print filename + " already exists!\n"
					@videos.delete(@file)
				end # if !File::exist?(filename)
				return true
			end # if line.match(season + "-" + ep)
		end # data.split("\n").each do |line|
	end # resp.code == 404
	return false
end # def rename

def show_to_url
	url = ""
	if !@show.index(' ')
		url=@show.downcase
		url[0] = url[0].chr.upcase
		@show = url
	else
		s = "#{@show}"
		show = ""
		s.downcase.split(' ').each do |showpiece|
			if !show.empty?
				showpiece[0] = showpiece[0].chr.upcase
				show = show + " " +  showpiece
			else
				showpiece[0] = showpiece[0].chr.upcase
				show = showpiece
			end # if !show.empty?
		end #s.downcase.split(' ').each do |showpiece|
		@show = show
		url = @show.delete(' ')
		if url[0,3] == "The" then url = url[3,url.length] end
	end #if !show.index(' ')
	return url
end # def show_to_url

def parse_showname(pieces)
	pieces.each do |piece|
		if p = piece.match(/^[sS]([0-9]{1,2})[eE]([0-9]{1,3})/)
			@season = p[1]
			@episode = p[2]
			if(@season[0].chr == '0') then @season.delete!("0") end
			if(@episode[0].chr == '0') then @episode.delete!("0") end
			break
		elsif p = piece.match(/^[sS]([0-9]{1,2})$/)
			@season = p[1]
			if(@season[0].chr == '0') then @season.delete!("0") end
			if(@episode) then break end
		elsif p = piece.match(/^[eE]([0-9]{1,3})$/)
			@episode = p[1]
			if(@episode[0].chr == '0') then @episode.delete!("0") end
			if(@season) then break end
		elsif p = piece.match(/^([0-9]{1,2})[xX]([0-9]{1,3})/)
			@season = p[1]
			@episode = p[2]
			if(@season[0].chr == '0') then @season.delete!("0") end
			if(@episode[0].chr == '0') then @episode.delete!("0") end
			break
		elsif ((p = piece.match(/^[0-9]{3,4}/)) && !(@show.downcase == "the" || @show.downcase == "sealab")) # Work around for "The 4400" and "Sealab 2021"
			piece = p.to_s
			if piece.length == 3
				@season = piece[0].chr
				@episode = piece[1..2]
				if(@episode[0].chr == '0') then @episode.delete!("0") end
			else
				@season = piece[0..1]
				@episode = piece[2..3]
				if(@season[0].chr == '0') then @season.delete!("0") end
				if(@episode[0].chr == '0') then @episode.delete!("0") end
			end # if piece.length
			break
		else
			if !@show
				@show = piece
			else
				@show = @show + " " + piece
			end # if show == ""
		end # if p = piece.match(/[sS][0-9]{1,2}[eE][0-9]{1,2}/)
	end # pieces.each do |piece|
	if (!@season || !@episode)
		return false
	else
		return true
	end
end # def match(pieces)

end # class Renamer

debug = false
norename = false
if ARGV.size > 0
	ARGV.each do |arg|
		case arg
			when "--debug":
				debug = true
			when "--no-rename"
				norename = true
			when "-n"
				norename = true
		end
	end			
end

Renamer.new

print "Press enter to continue..."
gets()
