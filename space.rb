#!/usr/bin/env ruby

movies = Dir['*.{avi,wmv,divx,mpg,mpeg,xvid,mp4,mkv}']

movies.each do |movie|
	rename = movie.gsub(/([^ ])-([^ ])/, '\1 - \2')
	File::rename(movie, rename)
end
