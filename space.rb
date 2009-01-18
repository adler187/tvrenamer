#!/usr/bin/env ruby

movies = Dir['*.{avi,wmv,divx,mpg,mpeg,xvid,mp4,mkv}']

movies.each do |movie|
	rename = movie
	while(rename.match(/[^ ]-[^ ]/))
		rename = rename.gsub(/([^ ])-([^ ])/, '\1 - \2')
	end
	File::rename(movie, rename)
end
