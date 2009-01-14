#!/usr/bin/env ruby

# Renamer2.rb
# Version 3.1
# Copyright 2007 Kevin Adler
# License: GPL v2

require 'net/http'
require 'date'
require 'cgi'

class Renamer

def initialize(args)

	@debug = false
	@norename = false
	i=0
	while i < args.size
 		case args[i]
 			when "-i"
 				@shows = args[i+1]
				if @shows.nil?
					p "You must enter the path to the shows.ini file"
					exit
				end
				i += 1
			when "--debug"
				@debug = true
			when "--no-rename", "-n"
				@norename = true
			when "--overwrite", "-o"
				@overwrite = true
 		end
		i += 1
	end
	
	if(!@shows)
		#check if windows or linux
		if RUBY_PLATFORM['linux']
			@shows = '/home/zeke/shows.ini'
		else
			output = Array.new
			IO.popen( 'cmd.exe' , "r+" ) do  | shell |
				shell.puts "echo %HOMEDRIVE%%HOMEPATH%"
				shell.close_write()
				shell.each do |l|
					output << l.chomp
				end
			end
			path = nil
			output.each_index do |i|
				if output[i].match('echo %HOMEDRIVE%%HOMEPATH%')
					path = output[i+1]
					break
				end
			end
			if path
				@shows =  path + '\\shows.ini'
			end
		end
	end

	begin	 
		@ini = Ini.new(@shows, true)
	rescue
		print @shows + " does not exist, no custom renaming available\n"
		@ini = nil
	end
  
	splits = [ ' ', '.' ]
	@video_list = Dir['*.{avi,wmv,divx,mpg,mpeg,xvid,mp4,mkv}'].sort
	
	@videos = Hash.new
	@video_list.each do | video|
		@videos[video] = false
	end
	#@videos = @videos.sort{|a,b| a[0].downcase <=> b[0].downcase}
	
	splits.each do |char|
		movies = @video_list.dup
		movies.each do |movie|
			@file = movie
			movie = movie.delete("[]").gsub(" - ", " ").gsub(/\([-\w]+\)/, '')
			pieces = movie.match(/[.][a-zA-Z]+$/).pre_match.split(char)
			
			if pieces.length > 1 
				@show = nil
				@season = nil
				@episode = nil
				@extension = movie.split('.')[-1]
				
				if datematch = movie.match(/(\d\d\.\d\d\.\d{4})/)
					date = datematch[1].gsub('.', '/')
					@date = Date.parse(date).strftime("%d %b %y")
					@date = @date[1..-1] if @date[0..0] == '0'
					movie = movie.gsub(/(\d\d\.\d\d\.\d{4})/, '[date]')
					pieces = movie.match(/[.][a-zA-Z]+$/).pre_match.split(char)
				else
					@date = nil
				end
				
				# parse the show into @show, @season, @episode, etc...
				if !parse_showname(pieces)
					if  !@videos[movie] # only display if on the first pass
						print "I could not match " + movie + " to a naming pattern I can interpret\n"
						@videos[movie] = true # set the warning flag
					end
				else
					# try to rename the file
					rename_status = rename()

					if rename_status == false #page exists, but episodes not listed
						print "Epguides does not have " + @show + " season: " + @season + " episode: " + @episode + " in it's guides.\n"

						# we parsed the file, but we can't rename it so don't try bothering to parse it again
						# so just remove it from the list
						@videos.delete(@file)	
					elsif !rename_status.nil? && !rename_status
						print "Response: " + rename_status
					elsif rename_status == "404" # rename failed
						if !@ini.nil?
							if @ini[@show.downcase]
								if @ini[@show.downcase]["url"]
									print "The entry for \"" + @show + "\" has an invalid URL\n"
								else @ini[@show.downcase]
									print "The entry for \"" + @show + "\" needs a URL\n"
								end	
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
	Dir['*.renamer'].each do |filename|
		File::delete(filename)
	end
end # def initialize

def rename()
	
	if @ini.nil?
		show = nil
	else
		show = @ini[@show.downcase]
	end
	# if we couldn't load the ini file or this show
	# doesn't have a url entry, try to create the url
	# from the file info
	if show.nil? or show["url"].nil?
		url = show_to_url()
	# otherwise, we use the url that is listed in the in file
	else
		url = show["url"]
	end
	
	if !File::exist?(url + ".renamer")
		page = Net::HTTP.new('www.epguides.com', nil)
		begin
			resp, data = page.get('/' + url  + '/')
		rescue
			print "Error loading www.epguides.com/" + url + "/\n"
			return nil;
		end
		File.open(url + ".renamer", "w") do |file|
			file << data
		end
	else
# 		page = Net::HTTP.new('www.epguides.com', nil)
# 		begin
# 			resp, data = page.get('/' + url  + '/')
# 		rescue
# 			print "Error loading www.epguides.com/" + url + "/\n"
# 			return nil;
# 		end
		data = File.new(url + ".renamer").read
		resp = Net::HTTPResponse.new('1.1', "200", 'OK')
	end
	
	
	# if there was an error, return the error code
	if resp.code != "200"
		return resp.code
	# we found the page, so rename it!
	else
		# get each line
		lines =  data.split(/\n|\r/)
		# go through each until we find the show data
		lines.each do |line|
			if !show.nil? && show["renamebydate"] && @date
				matchstring = @date
			else
				ep = "#{@episode}"
				
				# pad with spaces if necessary
				if(@episode.length < 2) then ep = " " + ep end
				matchstring = @season + "-" + ep
			end
			
			# there are two formats on epguides, one has links to TV.com
			# others are not listed at TV.com, so are linkless. To handle
			# both, we need to first find the line the show info is on,
			# then try to match based on the link or the plain data
			if line.match(matchstring)
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
					match = line.match(/(\d\d?-\s*\d+)\s+([0-9a-zA-Z\/-]+)?\s+(\d{1,2} \w{3} \d{2})?\s+<a.+">([0-9a-zA-Z\-!: ',?`~#¡\/\$%^&*();".+=-_]+)/)
					name = ""
					date = " "
					code = " "
					
					if !@season
						seasonmatch = match[1].match(/(\d\d?)- ?(\d+)/)
						@season = seasonmatch[1]
						@episode = seasonmatch[2]
					end
					# not every episode lists all the data, so we have to try and figure it out
					case match.length
						# if we have everything, it is rather easy
						when 5
							name = match[4]
							unless match[3].nil? then date = match[3] end
							unless match[2].nil? then code = match[2] end
						# if there are only 2 items, then it's a little more difficult
						when 4
							name = match[3]
							# dates have spaces in them, but AFAICT no production codes have spaces
							# so it is a pretty good test, outside of testing the regex again
							if match[2].include?(" ")
								date = match[2]
							else
								code = match[2]
							end
						# it's also pretty easy if there is only one thing
						when 3
							name = match[2]
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
				if (!show.nil? and show["mask"]) or @ini["mask"]
					# set the filename to the mask as a base

					# first we set it to the @ini mask
					filename = @ini["mask"].dup

					# then if a show specific mask exists, we override the global one
					if !show.nil? and !show["mask"].nil?
						filename = show["mask"].dup
					end

					# substitute the patterns with the data we found
					filename.gsub!("%show%", @show)
					filename.gsub!("%episode%", name)
					filename.gsub!("%season%", @season)
					filename.gsub!("%epnumber%", @episode)

					# if there is a custom date format, use that
					# otherwise date is however epguides displays it
					
					if date != ' ' && @ini
						format = nil
						if !show.nil? and show["dateformat"]
							format = show["dateformat"]
						elsif @ini["dateformat"]
							format = @ini["dateformat"]
						end
						if format
							date.insert(-3, "20")
							date = Date.parse(date).strftime(format)
						end
					end


					# TODO: we need to handle this better if date, code, etc.. don't exists
					# right now they just end up as spaces
					filename.gsub!("%date%", date)
					filename.gsub!("%code%", code)
				# if we don't have a shows.ini, or nothing specific is set, use the default pattern
				else
          print "no mask"
					filename = @show + " - " + @season + " - " + @episode + " - " + name
				end

				# add on the extension
				filename += "." + @extension

				# replace html encoded characters
				filename = CGI.unescapeHTML(filename)
				
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
					print "Can't rename " + @file + " to " + filename + "!\n"
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
	date = false
	pieces.each do |piece|
		if match = piece.match(/^[sS]([0-9]{1,2})[eE]([0-9]{1,3})/)
			@season = match[1]
			@episode = match[2]
			if(@season[0].chr == '0') then @season.delete!("0") end
			if(@episode[0].chr == '0') then @episode.delete!("0") end
			break
		elsif match = piece.match(/^[sS]([0-9]{1,2})$/)
			@season = match[1]
			if(@season[0].chr == '0') then @season.delete!("0") end
			if(@episode) then break end
		elsif match = piece.match(/^[eE]([0-9]{1,3})$/)
			@episode = match[1]
			if(@episode[0].chr == '0') then @episode.delete!("0") end
			if(@season) then break end
		elsif match = piece.match(/^([0-9]{1,2})[xX]([0-9]{1,3})/)
			@season = match[1]
			@episode = match[2]
			if(@season[0].chr == '0') then @season.delete!("0") end
			if(@episode[0].chr == '0') then @episode.delete!("0") end
			break
		elsif ((match = piece.match(/^[0-9]{3,4}/)) and
			  !(
					@show.downcase == "the" || # Work around for "The 4400"
					@show.downcase == "sealab" || # Work around for "Sealab 2021"
					(@show.downcase == "knight rider" and match.to_s == "2008") # Work around for "Knight Rider 2008"
			   )
			  )
			piece = match.to_s
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
		elsif piece == "[date]"
			date = true
		else
			if !date
				if !@show
					@show = piece
				else
					@show = @show + " " + piece
				end # if show == ""
			end
		end # if match = piece.match(/[sS][0-9]{1,2}[eE][0-9]{1,2}/)
	end # pieces.each do |piece|

	if !@ini || !@ini[@show.downcase] || !@ini[@show.downcase]["renamebydate"] || @ini[@show.downcase]["renamebydate"] != "true"
		return @season && @episode
	else
		return !@date.nil?
	end
end # def match(pieces)

end # class Renamer

# Ini class - read and write ini files
# Copyright (C) 2007 Jeena Paradies
# License: GPL
# Author: Jeena Paradies (info@jeenaparadies.net)

class Ini

# :inihash is a hash which holds all ini data
# :comment is a string which holds the comments on the top of the file
	attr_accessor :inihash, :comment

# Creating a new Ini object
# +path+ is a path to the ini file
# +load+ if nil restores the data if possible
#        if true restores the data, if not possible raises an error
#        if false does not resotre the data
def initialize(path, load=nil)
	@path = path
	@inihash = {}

	if load or ( load.nil? and FileTest.readable_real? @path )
		restore()
	end
end

# Retrive the ini data for the key +key+
def [](key)
	@inihash[key]
end

# Set the ini data for the key +key+
def []=(key, value)
	raise TypeError, "String expected" unless key.is_a? String
	raise TypeError, "String or Hash expected" unless value.is_a? String or value.is_a? Hash

	@inihash[key] = value
end

# Restores the data from file into the object
def restore()
	@inihash = Ini.read_from_file(@path)
	@comment = Ini.read_comment_from_file(@path)
end

# Store data from the object in the file
def update()
	Ini.write_to_file(@path, @inihash, @comment)
end

# Reading data from file
# +path+ is a path to the ini file
# returns a hash which represents the data from the file
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

# Reading comments from file
# +path+ is a path to the ini file
# Returns a string with comments from the beginning of the
# ini file.
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

# Writing a ini hash into a file
# +path+ is a path to the ini file
# +inihash+ is a hash representing the ini File. Default is a empty hash.
# +comment+ is a string with comments which appear on the
#           top of the file. Each line will get a "#" before.
#           Default is no comment.
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

# Turn a hash (up to 2 levels deepness) into a ini string
# +inihash+ is a hash representing the ini File. Default is a empty hash.
# Returns a string in the ini file format.
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

begin
	Renamer.new(ARGV)
rescue Exception
	puts $!, $@
end

if !RUBY_PLATFORM['linux']
	puts "Press enter to continue..."
	gets
end
