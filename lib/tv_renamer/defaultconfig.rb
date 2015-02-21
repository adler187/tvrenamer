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
  if RUBY_PLATFORM['linux']
    if ENV['XDG_CONFIG_HOME']
      BASEDIR = ENV['XDG_CONFIG_HOME']
    else
      if ENV['HOME']
        BASEDIR = File.join(ENV['HOME'], '.config')
      else
        STDERR.puts '$XDG_CONFIG_HOME and $HOME unset, falling back to current directory'
        BASEDIR = '.'
      end
    end
  else
    BASEDIR = ENV['HOMEDRIVE'] + ENV['HOMEPATH']
  end
  
  DEFAULT_CONFIG = File.join(BASEDIR, 'tv_renamer.yml')
end