# Copyright (C) 2011-2015 Kevin Adler
#
# This file is part of tv_renamer.
#
# tv_renamer is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# tv_renamer is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with tv_renamer.  If not, see <http://www.gnu.org/licenses/>.

require 'rubygems'
require 'net/http'
require 'fileutils'
require 'yaml'

module TvRenamer
  class Renamer
    DEFAULT_MASK = '%show%-%season%-%epnumber%-%episode%'
    
    def initialize(options)
      @options = options

      begin
        @config = YAML.load(File.read(@options[:config]))
        @config['global'] ||= { 'mask' => DEFAULT_MASK }
        
        global = @config['global']
        shows = @config['shows'] || {}
        
        unless shows.empty?
          shows.keys.each do |key|
            shows[key] = global.merge shows[key]
          end
        end
      rescue
        puts "#{@options[:config]} does not exist, no custom renaming available"
        @config = { 'global' => { 'mask' => DEFAULT_MASK } }
      end
    end

    def run
      files = Dir['*.{avi,wmv,divx,mpg,mpeg,xvid,mp4,mkv}'].sort

      files.each do |file|
        video = VideoFile.new(file, @config)

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

    def rename(video)
      return false unless set_attributes_from_epguides(video)

      # pad the episode with 0 if length is less than 0, we need to handle
      # this better for 3+ digit episodes seasons
      video.episode_number = sprintf("%02i", video.episode_number.to_i)

      return false unless new_filename = video.filename

      new_filename = [@options[:directory], new_filename].join(File::Separator)

      if !@options[:rename] or @options[:verbose]
        puts "rename #{video.original_filename} to #{new_filename}"
      end

      if @options[:rename]
        # if the file doesn't exist (or we allow overwrites), we rename it
        if !File::exist?(new_filename) or @options[:overwrite]
          begin
            FileUtils.mv(video.original_filename, new_filename)
            @one_rename_succeeded = true
            puts "rename succeeded"
          rescue Exception
            @one_rename_failed = true
            puts "rename failed"
          end
        # otherwise we don't overwrite it and just display a message
        else
          puts "Can't rename #{video.original_filename} to #{new_filename}!"
          puts "#{video.original_filename} already exists!"
          @one_rename_failed = true
        end
      end
    end
  end # class Renamer
end # module TvRenamer
