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
require 'date'

class Renamer

def initialize

	#check if windows or linux
	if RUBY_PLATFORM['linux']
		@shows = '/home/zeke/shows.ini'
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
			@shows = 'C:' + path + '\\shows.ini'
		end
	end

	begin	
		@ini = Ini.new(@shows, true)
	rescue
		print @shows + " does not exist, no custom renaming available\n"
		@ini = nil
	end
	
	splits = [ ' ', '.' ]
	@video_list = Dir['*.{avi,wmv,divx,mpg,mpeg,xvid,mp4,mkv}']
	@videos = Hash.new
	@video_list.each do | video|
		@videos[video] = false
	end
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

				# parse the show into @show, @season, @episode, etc...
				if !parse_showname(pieces)
					if  !warned # only display if on the first pass
						print "I could not match " + movie + " to a naming pattern I can interpret\n"
						@videos[movie] = true # set the warning flag
					end
				else
					# try to rename the file
					rename_status = rename()
					
					if !rename_status #page exists, but episodes not listed
						print "Epguides does not have " + @show + " season: " + @season + " episode: " + @episode + " in it's guides.\n"
						
						# we parsed the file, but we can't rename it so don't try bothering to parse it again
						# so just remove it from the list
						@videos.delete(@file)
					elsif rename_status == "404" # rename failed 
						if !@ini.nil?
							if @ini[@show]["url"]
								print "The entry for \"" + @show + "\" has an invalid URL\n"
							elsif @ini[@show]
								print "The entry for \"" + @show + "\" needs a URL\n"
							else
								print "Please add an alias of the epguide.com show url for \"" + @show + "\" to " + @shows + "\n"
							end
						else
							print @shows + " does not exist, will not be able to locate this show without help\n"
						end # if !@ini.nil?

						# we parsed the file, but we can't rename it so don't try bothering to parse it again
						# so just remove it from the list
						@videos.delete(@file)
					end # if !rename_status
				end # if !parse_showname(pieces)
			end # if pieces.length < 2
		end # movies.each do |movie|
	end # splits.each do |char|
end # def initialize

def rename()
	show = @ini[@show]

	# if we couldn't load the ini file or this show
	# doesn't have a url entry, try to create the url
	# from the file info
	if show.nil? or show["url"].nil?
		url = show_to_url()
	# otherwise, we use the url that is listed in the in file
	else
		url = show["url"]
	end
	
	page = Net::HTTP.new('www.epguides.com', nil)
	begin
		resp, data = page.get('/' + url  + '/')
	rescue
		print "Error loading www.epguides.com/" + url + "/\n"
	end
		
	#if we couldn't find it, return the error code
	# TODO: If we get a different code, that isn't success
	# (200?) we should probably handle this better
	if resp.code == "404"
		return resp.code
	# we found the page, so rename it!
	else
		# get each line
		lines =  data.split(/(\n|\r)/)
		# go through each until we find the show data
		lines.each do |line|
		
			ep = "#{@episode}"

			# pad with spaces if necessary
			if(@episode.length < 2) then ep = " " + ep end

			# there are two formats on epguides, one has links to TV.com
			# others are not listed at TV.com, so are linkless. To handle
			# both, we need to first find the line the show info is on,
			# then try to match based on the link or the plain data
			if line.match(@season + "-" + ep)
				if line.match("<li>")
					name = line[35,line.length]
					name.delete!("\r")
					date = line[23..31].strip
					code = line[12..19].strip
					date = " " unless date != ""
					code = " " unless code != ""
				else
					# this is not complete, as it is missing certain characters that may be in episode names,
					# such as fancy european characters. TODO: add those
					match = line.match(/([0-9a-zA-Z-]+)?\s+(\d{1,2} \w{3} \d{2})?\s+<a.+">([0-9a-zA-Z\-!: ',?`~#¡\/\$%^&*()".+=-_]+)/)
					name = ""
					date = " "
					code = " "
					# not every episode lists all the data, so we have to try and figure it out
					case match.length
						# if we have everything, it is rather easy
						when 4
							name = match[3]
							date = match[2]
							code = match[1]
						# if there are only 2 items, then it's a little more difficult
						when 3
							name = match[2]
							# dates have spaces in them, but AFAICT no production codes have spaces
							# so it is a pretty good test, outside of testing the regex again
							if match[1].include?(" ")
								date = match[1]
							else
								code = match[1]
							end
						# it's also pretty easy if there is only one thing
						when 2
							name = match[1]
					end
					
				end # if line.match("<li>")

				# if the ini exists, we set the showname to the custome name if it exists
				if !show.nil?
					@show = show["customname"] unless show["customname"].nil?
				end

				# pad the episode with 0 if length is less than 0, we need to handle
				# this better for 3+ digit episodes seasons
				if @episode.length < 2 then @episode = "0" + @episode end

				# if the ini file exists, and they set a custom renaming mask,
				# or a global one exists we need to do more custom renaming
				if !show.nil? and (show["mask"] or @ini["mask"])
					# set the filename to the mask as a base

					# first we set it to the @ini mask
					filename = @ini["mask"]

					# then if a show specific mask exists, we override the global one
					filename = show["mask"] unless show["mask"].nil?

					# substitute the patterns with the data we found
					filename.gsub!("%show%", @show)
					filename.gsub!("%episode%", name)
					filename.gsub!("%season%", @season)
					filename.gsub!("%epnumber%", @episode)

					# if there is a custom date format, use that
					# otherwise date is however epguides displays it
					if @ini["dateformat"] or show["dateformat"]
						format = @ini["dateformat"]
						format = show["dateformat"] unless show["dateformat"].nil?
						date.insert(-3, "20")
						date = Date.parse(date).strftime(format)
					end


					# TODO: we need to handle this better if date, code, etc.. don't exists
					# right now they just end up as spaces
					filename.gsub!("%date%", date)
					filename.gsub!("%code%", code)
					
				# if we don't have a shows.ini, or nothing specific is set, use the default pattern
				else
					filename = @show + " - " + @season + " - " + @episode + " - " + name
				end

				# add on the extension
				filename += "." + @extension

				# replace these illegal win32 characters with '-'
				filename.gsub!(":", "-")
				filename.gsub!("/", "-")

				# just delete theses illegal win32 characters
				filename.delete!("?\\/<>\"")

				# TODO: Regression - Add command line option to allow overwrites
				# if the file doesn't exist, we rename it
				if !File::exist?(filename) # or @overwrite
					File::rename(@file, filename)

				# otherwise we don't overwrite it and just display a message
				else
					print "Can't rename " + @file + "!\n"
					print filename + " already exists!\n"
				end # if !File::exist?(filename)
				
				@videos.delete(@file) # remove the file so we don't try to rename it again 
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


#
# ini.rb - read and write ini files
#
# Copyright (C) 2007 Jeena Paradies
# License: GPL
# Author: Jeena Paradies (info@jeenaparadies.net)
#
# == Overview
#
# This file provides a read-wite handling for ini files.
# The data of a ini file is represented by a object which
# is populated with strings.

class Ini

# Class with methods to read from and write into ini files.
#
# A ini file is a text file in a specific format,
# it may include several fields which are sparated by
# field headlines which are enclosured by "[]".
# Each field may include several key-value pairs.
#
# Each key-value pair is represented by one line and
# the value is sparated from the key by a "=".
#
# == Examples
#
# === Example ini file
#
#   # this is the first comment which will be saved in the comment attribute
#   mail=info@example.com
#   domain=example.com # this is a comment which will not be saved
#   [database]
#   db=example
#   user=john
#   passwd=very-secure
#   host=localhost
#   # this is another comment
#   [filepaths]
#   tmp=/tmp/example
#   lib=/home/john/projects/example/lib
#   htdocs=/home/john/projects/example/htdocs
#   [ texts ]
#   wellcome=Wellcome on my new website!
#   Website description = This is only a example. # and another comment
#
# === Example object
#
#   A Ini#comment stores:
#   "this is the first comment which will be saved in the comment attribute"
#
#   A Ini object stores:
#
#   {
#    "mail" => "info@example.com",
#    "domain" => "example.com",
#    "database" => {
#     "db" => "example",
#     "user" => "john",
#     "passwd" => "very-secure",
#     "host" => "localhost"
#    },
#    "filepaths" => {
#     "tmp" => "/tmp/example",
#     "lib" => "/home/john/projects/example/lib",
#     "htdocs" => "/home/john/projects/example/htdocs"
#    }
#    "texts" => {
#     "wellcome" => "Wellcome on my new website!",
#     "Website description" => "This is only a example."
#    }
#   }
#
# As you can see this module gets rid of all comments, linebreaks
# and unnecessary spaces at the beginning and the end of each
# field headline, key or value.
#
# === Using the object
#
# Using the object is stright forward:
#
#   ini = Ini.new("path/settings.ini")
#   ini["mail"] = "info@example.com"
#   ini["filepaths"] = { "tmp" => "/tmp/example" }
#   ini.comment = "This is\na comment"
#   puts ini["filepaths"]["tmp"]
#   # => /tmp/example
#   ini.write()
#

#
# :inihash is a hash which holds all ini data
# :comment is a string which holds the comments on the top of the file
#
	attr_accessor :inihash, :comment

#
# Creating a new Ini object
#
# +path+ is a path to the ini file
# +load+ if nil restores the data if possible
#        if true restores the data, if not possible raises an error
#        if false does not resotre the data
#
def initialize(path, load=nil)
	@path = path
	@inihash = {}

	if load or ( load.nil? and FileTest.readable_real? @path )
		restore()
	end
end

#
# Retrive the ini data for the key +key+
#
def [](key)
	@inihash[key]
end

#
# Set the ini data for the key +key+
#
def []=(key, value)
	raise TypeError, "String expected" unless key.is_a? String
	raise TypeError, "String or Hash expected" unless value.is_a? String or value.is_a? Hash

	@inihash[key] = value
end

#
# Restores the data from file into the object
#
def restore()
	@inihash = Ini.read_from_file(@path)
	@comment = Ini.read_comment_from_file(@path)
end

#
# Store data from the object in the file
#
def update()
	Ini.write_to_file(@path, @inihash, @comment)
end

#
# Reading data from file
#
# +path+ is a path to the ini file
#
# returns a hash which represents the data from the file
#
def Ini.read_from_file(path)
	inihash = {}
	headline = nil


	IO.foreach(path) do |line|

		line = line.strip.split(/#/)[0]

		# if line is nil, just go to the next one
		next if line.nil?

		# read it only if the line doesn't begin with a "=" and is long enough
		unless line.length < 2 and line[0,1] == "="

			# it's a headline if the line begins with a "[" and ends with a "]"
			if line[0,1] == "[" and line[line.length - 1, line.length] == "]"

				# get rid of the [] and unnecessary spaces
				headline = line[1, line.length - 2 ].strip
				inihash[headline] = {}
			else

				key, value = line.split(/=/, 2)

				key = key.strip unless key.nil?
				value = value.strip unless value.nil?

				unless headline.nil?
					inihash[headline][key] = value
				else
					inihash[key] = value unless key.nil?
				end
			end
		end
	end

	inihash
end

#
# Reading comments from file
#
# +path+ is a path to the ini file
#
# Returns a string with comments from the beginning of the
# ini file.
#
def Ini.read_comment_from_file(path)
	comment = ""

	IO.foreach(path) do |line|
		line.strip!
		next if line.nil?

		next unless line[0,1] == "#"

		comment << "#{line[1, line.length ].strip}\n"
	end

	comment
end

#
# Writing a ini hash into a file
#
# +path+ is a path to the ini file
# +inihash+ is a hash representing the ini File. Default is a empty hash.
# +comment+ is a string with comments which appear on the
#           top of the file. Each line will get a "#" before.
#           Default is no comment.
#
def Ini.write_to_file(path, inihash={}, comment=nil)
	raise TypeError, "String expected" unless comment.is_a? String or comment.nil?

	raise TypeError, "Hash expected" unless inihash.is_a? Hash
	File.open(path, "w") { |file|

		unless comment.nil?
			comment.each do |line|
				file << "# #{line}"
			end
		end

		file << Ini.to_s(inihash)
	}
end

#
# Turn a hash (up to 2 levels deepness) into a ini string
#
# +inihash+ is a hash representing the ini File. Default is a empty hash.
#
# Returns a string in the ini file format.
#
def Ini.to_s(inihash={})
	str = ""

	inihash.each do |key, value|
		if value.is_a? Hash
			str << "[#{key.to_s}]\n"

			value.each do |under_key, under_value|
				str << "#{under_key.to_s}=#{under_value.to_s unless under_value.nil?}\n"
			end

		else
			str << "#{key.to_s}=#{value.to_s unless value2.nil?}\n"
		end
	end

	str
	end

end # end class
										

Renamer.new

print "Press enter to continue..."
gets()
