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

module TvRenamer
  class VideoFile
    SPLITS = [ ' ', '.' ]

    attr_accessor :orig_show, :season, :episode_number, :episode_name, :extension, :filename, :date, :production_code, :format

    def show
      @orig_show ||= show_name_from_tokens
      @show ? @show : @orig_show
    end

    def show=(show)
      @show = show
    end

    def show_name
      @name = @name || @config['customname'] || show
    end

    def rename_by_date
      @config['renamebydate']
    end

    def config(option)
      @config[option]
    end

    def to_s
      [show, @season, @episode_number, @date, @production_code, @episode_name].join(' : ')
    end

    def initialize(filename, config)
      @config = {}

      parse(filename)

      @config = config['shows'][show_name_from_tokens.downcase] || config['global']
    end

    def parsed_ok?
      show && ((@episode_number && @season) || (@config['renamebydate'] && @date))
    end

  private
    def parse(filename)
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
end