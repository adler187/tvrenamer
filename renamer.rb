#!/usr/bin/env ruby

# renamer.rb
# Version 4.0.0
# Copyright 2011 Kevin Adler
# License: GPL v2


begin
  require 'rubygems'
  require 'net/http'
  require 'date'
  require 'cgi'
  require 'fileutils'
  require 'nokogiri'
rescue LoadError => e
  required_file = e.to_s.split(' -- ')[1]
  puts "Cannot find #{required_file}, try doing 'gem install #{required_file}', then retry the command"
  exit 1
end

class VideoFile
  SPLITS = [ ' ', '.' ]

  attr_accessor :orig_show, :season, :episode_number, :episode_name, :extension, :filename, :date, :production_code, :format, :rename_by_date

  def show
    @orig_show ||= show_name_from_tokens
    @show ? @show : @orig_show
  end

  def show=(show)
    @show = show
  end

  def to_s
    [show, @season, @episode_number, @date, @production_code, @episode_name].join(' : ')
  end

  def initialize(filename)
    @filename = filename
    @extension ||= @filename.split('.').pop
    @show_pieces = Array.new

    cleaned_filename = @filename.delete("[]").gsub(" - ", " ").gsub(/\([-\w]+\)/, '')

    if date_match = cleaned_filename.match(/\d\d\.\d\d\.\d{4}/)
      @date = Date.parse(date_match[0].gsub('.', '/')).strftime("%d %b %y")

      # remove leading zeros
      @date = @date[1..-1] if @date[0..0] == '0'

      # remove date from filename to prevent matching parts of date as season or episode number
      cleaned_filename = [date_match.pre_match, date_match.post_match].join('[date]')
    end

    SPLITS.each do |char|
      clear_variables

      pieces = remove_extension(cleaned_filename).split(char)

      parse_showname(pieces) if pieces.length > 1

      break if parsed_ok?
    end
  end

  def clear_variables
    @orig_show = @show = @season = @episode_name = @episode_number = @production_code = @date = nil
    @show_pieces = Array.new
  end

  def parsed_ok?
    show && ((@episode_number && @season) || (@rename_by_date && @date))
  end

  def parse_showname(pieces)
    date = false
    pieces.each do |piece|
      if match = piece.match(/^[sS]([0-9]{1,2})[eE]([0-9]{1,3})$/)
        @season = match[1]
        @episode_number = match[2]
        if(@season[0].chr == '0') then @season.delete!("0") end
        if(@episode_number[0].chr == '0') then @episode_number.delete!("0") end
        break
      elsif match = piece.match(/^[sS]([0-9]{1,2})$/)
        @season = match[1]
        if(@season[0].chr == '0') then @season.delete!("0") end
        if(@episode_number) then break end
      elsif match = piece.match(/^[eE]([0-9]{1,3})$/)
        @episode_number = match[1]
        if(@episode_number[0].chr == '0') then @episode_number.delete!("0") end
        if(@season) then break end
      elsif match = piece.match(/^([0-9]{1,2})[xX]([0-9]{1,3})$/)
        @season = match[1]
        @episode_number = match[2]
        if(@season[0].chr == '0') then @season.delete!("0") end
        if(@episode_number[0].chr == '0') then @episode_number.delete!("0") end
        break
      elsif
      (
        (match = piece.match(/^[0-9]{3,4}$/)) and
        !(
            show_name_from_tokens.downcase == "the" || # Work around for "The 4400"
            show_name_from_tokens.downcase == "sealab" || # Work around for "Sealab 2021"
            (show_name_from_tokens.downcase == "knight rider" and match.to_s == "2008") || # Work around for "Knight Rider 2008"
            (show_name_from_tokens.downcase == "90210" and match.to_s == "90210") # Work around for 90210
        )
      )
        piece = match.to_s
        if piece.length == 3
          @season = piece[0].chr
          @episode_number = piece[1..2]
          if(@episode_number[0].chr == '0') then @episode_number.delete!("0") end
        else
          @season = piece[0..1]
          @episode_number = piece[2..3]
          if(@season[0].chr == '0') then @season.delete!("0") end
          if(@episode_number[0].chr == '0') then @episode_number.delete!("0") end
        end

        break
      elsif piece == "[date]"
        date = true
      else
        if !date
          if !@orig_show
            @show_pieces.push camelize(piece)
          end
        end
      end
    end
  end


  private

  def camelize(string)
    string[0] = string[0].chr.upcase
    string
  end

  def remove_extension(file)
    file.gsub(".#{@extension}", '')
  end

  def show_name_from_tokens
    @show_pieces.join ' '
  end
end

class Renamer

def initialize(args)
  @output_dir = '.'
  @rename = true
  i=0
  while i < args.size
    case args[i]
      when "-i"
        @ini_file = args[i+1]
        if @ini_file.nil?
          puts "You must enter the path to the shows.ini file"
          exit
        end
        i += 1
      when "--output-dir", "-d"
        @output_dir = args[i+1]
        if @output_dir.nil?
          puts "You must enter a directory to renamer files to!"
          exit 1
        end
        i += 1
      when "--debug"
        @debug = true
      when "--no-rename", "-n"
        @rename = false
      when "--overwrite", "-o"
        @overwrite = true
      when "--verbose", "-v"
        @verbose = true
    end
    i += 1
  end

  if(!@ini_file)
    #check if windows or linux
    if !RUBY_PLATFORM['linux']
      @ini_file =  ENV['HOMEDRIVE'] + ENV['HOMEPATH'] + '\\shows.ini'
    else
      @ini_file = ENV['HOME'] + '/shows.ini'
    end
  end

  begin
    @ini = Ini.new(@ini_file, true)
  rescue
    puts "#{@ini_file} does not exist, no custom renaming available"
  end
end

def run
  files = Dir['*.{avi,wmv,divx,mpg,mpeg,xvid,mp4,mkv}'].sort

  files.each do |file|
    video = VideoFile.new(file)

    video.rename_by_date = true if video.show && attribute('renamebydate', video.orig_show)

    # parse the show into @show, @season, @episode_number, etc...
    if !video.parsed_ok?
      puts "I could not match #{file} to a naming pattern I can interpret"
      next
    end

    rename(video)
  end

  # delete the cached results from epguides
  Dir['*.renamer'].each do |filename|
    File::delete(filename)
  end

  if @one_rename_failed
    # if some renames succeeded, return 2
    if @one_rename_succeeded
      exit 2
    # if no renames succeeded, return 1
    else
      exit 1
    end
  end
end

def set_attributes_from_epguides(video)
  line = epguide_line(video)
  return false if line.nil?

  info = parse_line(line, video.format)
  return false if info.nil?

  season_episode = info[1]
  video.production_code = info[2]
  video.date = info[3]
  episode_name = info[4]

  if line.match("<li>")
    video.episode_name = episode_name
  else
    doc = Nokogiri::HTML("<pre>#{line}</pre>")
    links = doc.css('pre a')
    if links.empty?
      puts "Could not find episode name for #{video}"
    else
      video.episode_name = links[0].content
    end
  end

  seasonmatch = season_episode.match(/(\d\d?)- ?(\d+)/)
  video.season ||= seasonmatch[1]
  video.episode_number ||= seasonmatch[2]
end

def rename(video)
  return false unless set_attributes_from_epguides(video)

  # if the ini exists, we set the showname to the custome name if it exists
  if customname = attribute('customname', video.orig_show)
    video.show = customname
  end

  # pad the episode with 0 if length is less than 0, we need to handle
  # this better for 3+ digit episodes seasons
  video.episode_number = sprintf("%02i", video.episode_number.to_i)

  return false unless new_filename = generate_filename(video)

  new_filename = [@output_dir, new_filename].join(File::Separator)

  if !@rename or @verbose
    puts "rename #{video.filename} to #{new_filename}"
  end

  if @rename
    # if the file doesn't exist (or we allow overwrites), we rename it
    if !File::exist?(new_filename) or @overwrite
      begin
        FileUtils.mv(video.filename, new_filename)
        @one_rename_succeeded = true
        puts "rename succeeded"
      rescue Exception
        @one_rename_failed = true
        puts "rename failed"
      end
    # otherwise we don't overwrite it and just display a message
    else
      puts "Can't rename #{video.filename} to #{new_filename}!"
      puts filename + " already exists!"
      @one_rename_failed = true
    end
  end
end

def generate_filename(video)
  # if the ini file exists, and they set a custom renaming mask,
  # or a global one exists we need to do more custom renaming
  if mask = attribute('mask', video.orig_show)
    # set the filename to the mask as a base

    filename = mask.dup

    # substitute the patterns with the data we found
    filename.gsub!("%show%", video.show)
    filename.gsub!("%episode%", video.episode_name)
    filename.gsub!("%season%", video.season)
    filename.gsub!("%epnumber%", video.episode_number)

    # if there is a custom date format, use that
    # otherwise date is however epguides displays it
    if !video.date.nil? && date_format = attribute('dateformat', video.orig_show)
      video.date.insert(-3, "20")
      video.date = Date.parse(video.date).strftime(date_format)
    end

    # TODO: we need to handle this better if date, code, etc.. don't exists
    # right now they just end up as spaces
    filename.gsub!("%date%", video.date)
    filename.gsub!("%code%", video.production_code)
  # if we don't have a shows.ini, or nothing specific is set, use the default pattern
  else
    filename = [video.show, video.season, video.episode_number,  video.episode_name].join(' - ')
  end

  # add on the extension
  filename = "#{filename}.#{video.extension}"

  # replace html encoded characters
  filename = CGI.unescapeHTML(filename)

  # replace these illegal win32 characters with '-'
  filename.gsub!(":", "-")
  filename.gsub!("/", "-")

  # just delete theses illegal win32 characters
  filename.delete!("?\\/<>\"")

  filename
end

def epguide_data(video, url)
  if !File::exist?(url + ".renamer")
    page = Net::HTTP.new('www.epguides.com', nil)

    begin
      resp, data = page.get("/#{url}/")
    rescue
      puts "Error loading www.epguides.com/#{url}/"
      return nil;
    end

    if resp.code == "200"
      File.open(url + ".renamer", "w") do |file|
        file << data
      end
    else
      if resp.code == "404"
        if !@ini.nil?
          if @ini[video.show.downcase]
            if @ini[video.show.downcase]["url"]
              puts "The entry for \"#{video.show}\" has an invalid URL"
            else
              puts "The entry for \"#{video.show}\" needs a URL"
            end
          else
            puts "Please add an alias of the epguide.com show url for \"#{video.show}\" to #{@ini_file}"
          end
        else
          puts "#{@ini_file} does not exist, please create this file and add an alias for #{video.show}"
        end
      else
        puts "I don't know how to handle an HTTP #{resp.code}"
      end

      return nil
    end
  else
    File.open(url + ".renamer", "r") do |file|
      data = file.read
    end
  end

  return data
end

def attribute(attribute, show)
  if show
    attr = @ini[show.downcase][attribute] unless @ini.nil? or @ini[show.downcase].nil?
    if attr
      return attr
    else
      return attribute(attribute, nil)
    end
  else
    return @ini[attribute] unless @ini.nil?
  end
end

def matchstring(video, tvrage)
  if video.rename_by_date && video.date
    if !tvrage
      video.date
    else
      video.date.gsub(' ', '/')
    end
  else
    if !tvrage
      matchstring = "#{video.season}-#{sprintf('%2s', video.episode_number)}"
    else
      matchstring = "#{video.season}-#{sprintf('%02i', video.episode_number.to_i)}"
    end
  end
end

# returns the line of html from epguides.com that contains the information for this episode
def epguide_line(video)
  url = show_url(video)
  data = epguide_data(video, url)

  return nil if data.nil?

  # default to TV.com pages
  pattern = matchstring(video, false)

  # get each line
  lines =  data.split(/\n|\r/)

  # go through each until we find the show data
  lines.each do |line|
    if line =~ /((_+) )+/
      video.format = line
    elsif line.match(pattern)
      return line
    elsif line.match("this TVRage editor")
      pattern = matchstring(video, true)
    end
  end

  puts "Epguides does not have #{video.show} season: #{video.season} episode: #{video.episode_number} in its guides."
  nil
end

def parse_line(line, format)
  if format.nil?
    if line.match("<li>")
      format = "____ _______ ________ ___________ ______________________________________________"
    else
      format = "_____ ______ ___________  ___________ ___________________________________________"
    end

    puts "Couldn't find data format string from epguides page, assuming format like:"
    puts format
  end

  # ensure format ends in exactly one space so loop gets all tokens
  format = format.split(' ').join(' ') + ' '

  tokens = []
  prev_offset = -1
  while offset = format.index(' ', prev_offset + 1) do
    range = (prev_offset+1)..(offset - 1)
    tokens.push line.slice(range).strip
    prev_offset = offset
  end

  return tokens
end

def show_url(video)
  # use the url specified in the ini, if set
  url = attribute('url', video.show)

  if url.nil?
    url = video.show.split(' ').join

    url = url[3, url.length] if url[0,3] == "The"
  end

  url
end

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

end # end Ini

begin
  Renamer.new(ARGV).run
rescue SystemExit => e
  exit e.status
rescue Exception
  puts $!, $@
  exit 1
end

if !RUBY_PLATFORM['linux']
  puts "Press enter to continue..."
  STDIN.gets
end
