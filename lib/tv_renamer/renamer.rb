# renamer.rb
# Version 4.0.5
# Copyright 2011 Kevin Adler
# License: GPL v2

require 'rubygems'
require 'net/http'
require 'date'
require 'cgi'
require 'fileutils'
require 'nokogiri'

module TvRenamer
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
        if RUBY_PLATFORM['linux']
          if ENV['XDG_CONFIG_HOME']
            basedir = ENV['XDG_CONFIG_HOME']
          else
            if ENV['HOME']
              basedir = File.join(ENV['HOME'], '.config')
            else
              puts '$XDG_CONFIG_HOME and $HOME unset, falling back to current directory'
              basedir = '.'
            end
          end
        else
          basedir = ENV['HOMEDRIVE'] + ENV['HOMEPATH']
        end
        
        @ini_file = File.join(basedir, 'shows.ini')
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
          puts "#{video.filename} already exists!"
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
        page = Net::HTTP.new('www.epguides.com')

        response = page.get("/#{url}/")

        case response
        when Net::HTTPSuccess
          data = response.body
          
          File.open(url + ".renamer", "w") do |file|
            file << data
          end
        else
          if !@ini.nil?
            puts "#{@ini_file} does not exist, please create this file and add an alias for #{video.show}"
            return nil
          end
          
          unless @ini[video.show.downcase]
            puts "Please add an alias of the epguide.com show url for \"#{video.show}\" to #{@ini_file}"
            return nil
          end
          
          if @ini[video.show.downcase]["url"]
            puts "The entry for \"#{video.show}\" has an invalid URL"
          else
            puts "The entry for \"#{video.show}\" needs a URL"
          end

          data = nil
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
end # module TvRenamer
