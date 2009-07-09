#!/usr/bin/ruby

overwrite = false

if(!File::exists?("command.txt"))
	exit(0)
end

data = ''
f = File.open("command.txt", "r")
f.each_line do |line|
	data += line + ' '
end

dirs = Dir["*"]
dirs.each do |dir|
	if(File::directory?(dir))
		Dir::chdir(dir)
		if(File::exists?("temp.mkv") && !overwrite)
			Dir::chdir("..")
			next
		end
		movie = Dir["*.{avi,mkv}"][0]
		subs = Dir["*.idx"][0]
		command = data.gsub("(FILENAME)", "temp.mkv")
		if(movie != nil && subs != nil)
			command.gsub!("(AVI)", movie)
			command.gsub!("(SUBS)", subs)
			system(command)
		end		
		Dir::chdir("..")
	end
end
