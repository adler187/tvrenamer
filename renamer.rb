#!/usr/bin/env ruby

# Renamer2.rb
# Version 3.0
# Copyright 2007 Kevin Adler
# License: GPL v2

require 'net/http'
require 'date'

class Renamer

def initialize(args)

	@debug = false
	@norename = false
	if args.size > 0
		args.each do |arg|
			case arg
				when "--debug":
					@debug = true
				when "--no-rename"
					@norename = true
				when "-n"
					@norename = true
			end
		end
	end
	skipnext = false
	args.length.times do |i|
		if skipnext
			skipnext = false
			next
		end
		if(args[i] == '-i' || args[i] == '--ini')
			@shows = args[i+1]
			skipnext = false
		end
	end
	
	if(!@shows)
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
end # def initialize

def rename()
	show = @ini[@show.downcase]
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
					match = line.match(/([0-9a-zA-Z\/-]+)?\s+(\d{1,2} \w{3} \d{2})?\s+<a.+">([0-9a-zA-Z\-!: ',?`~#¡\/\$%^&*()".+=-_]+)/)
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
					filename = @ini["mask"].dup

					# then if a show specific mask exists, we override the global one
					filename = show["mask"].dup unless show["mask"].nil?

					# substitute the patterns with the data we found
					filename.gsub!("%show%", @show)
					filename.gsub!("%episode%", name)
					filename.gsub!("%season%", @season)
					filename.gsub!("%epnumber%", @episode)

					# if there is a custom date format, use that
					# otherwise date is however epguides displays it
					if date != ' ' and (@ini["dateformat"] or show["dateformat"])
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
		elsif ((p = piece.match(/^[0-9]{3,4}/)) and
			  !(
					@show.downcase == "the" || # Work around for "The 4400"
					@show.downcase == "sealab" || # Work around for "Sealab 2021"
					(@show.downcase == "knight rider" and p.to_s == "2008") # Work around for "Knight Rider 2008"
			   )
			  )
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

Renamer.new(ARGV)

# print "Press enter to continue..."
# gets()
