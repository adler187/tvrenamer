#!/usr/bin/env ruby

File.open("options.txt", "w") do |file|
  file.print("-o\noutput.mkv\n--title\n#EMPTY#");
end

if RUBY_PLATFORM['linux']
	@mkvinfo = "mkvinfo "
else
	@mkvinfo = "mkvinfo.exe "
end
print @mkvinfo,"\n"

@overwrite = true
if ARGV.size > 0
	ARGV.each do |arg|
		case arg
			when "--no-overwrite":
				@overwrite = false
			when "-n"
				@overwrite = false
		end
	end			
end
videolist = Dir['*.mkv']
videolist.each do |file|
  file = file
  print "Remerging " + file + "\n"
	output = Array.new
	command = @mkvinfo + '"' + file + '"'
	#print command,"\n"
	IO.popen(command, "r+") do |shell|
		shell.each do |l|
			output << l.chomp
		end
	end
	output.each_index do |i|
		#p output[i]
		if output[i].match('Done with AutoMKV')
		command = 'mkvmerge @options.txt "' + file + '"'
		#	print command,"\n"
			#system(command)
      IO.popen(command, "r") do |shell|
        shell.each do |l|
          # p l
        end
      end
			if(@overwrite)
				File::delete(file)
			else
				File::rename(file, "automkv." +file)
			end
      File::rename("output.mkv", file)
			break
		end
	end
end

if(File::exists?("options.txt"))
  File::delete("options.txt")
end
