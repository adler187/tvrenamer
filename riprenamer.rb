#!/usr/bin/env ruby

# Ripper Renamer
# Version 1.0

# This program will get the contents of a directory
# and then go through each folder in the directory
# and rename each avi within that directory to the correct
# name and move it to the current directory


working_dir = Dir.pwd
split = working_dir.split('/')
show = split[split.length - 1]
files = Dir['*']
files.each do |file|
	if File::directory?(working_dir + "/" + file)
		Dir.chdir(working_dir + "/" + file)
		episode = Dir['*.{mkv,avi}'][0]
		if !episode
			print "This directory doesn't contain an encoded file!\n"
		else
			ep = file.delete(' ')
			ep = ep.split('-')
			if ep.length < 2
				print "The folder '" + file + "' is not in the proper name format\n"
			else
				ep = ep[0] + "x" + ep[1] + '.' + episode[episode.length-3..episode.length]
				filename = show + " " + ep
				File::rename(episode, filename)
				begin
					if RUBY_PLATFORM['linux']
						system("mv \"" + filename +  "\" ..")
					else
						system("move \"" + filename + "\" ..")
					end
				rescue
					puts $!, $@
					print file + " is in use, skipping."
				end
			end
		end
	end
end
