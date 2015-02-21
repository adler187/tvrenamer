# Copyright (C) 2015 Kevin Adler
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

require 'nokogiri'

module TvRenamer
#   class ShowInfo
  class Renamer
    def initialize()
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

    def epguide_data(video, url)
      cache_file = "#{url}.renamer"
      
      if File::exist?(cache_file)
        return File.open(url + ".renamer", "r").read
      end
        
      page = Net::HTTP.new('www.epguides.com')

      response = page.get("/#{url}/")

      if response.is_a? Net::HTTPSuccess
        File.open(url + ".renamer", "w") do |file|
          file << response.body
        end
        
        return response.body
      end
      
      if video.config('url')
        puts "The alias of \"#{video.config('url')}\" for \"#{video.show}\" is invalid!"
        return nil
      end
      
      puts <<-EOS
Please add an alias of the epguide.com show url for \"#{video.show}\" to #{@options[:config]}
NOTE: The url should only be the part after http://epguides.com/
eg. if this file is actually Battlestar Galactica (1978), the full url would be http://epguides.com/BattlestarGalactica_1978/
    you would add the following:
  
shows:
  "#{video.show.downcase}":
    url: BattlestarGalactica_1978
      EOS
            
      return nil
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
      # use the url specified in the config, if set
      url = video.config('url')

      if url.nil?
        url = video.show.split(' ').join

        url = url[3, url.length] if url[0,3] == "The"
      end

      url
    end
  end
end