#!/usr/bin/env ruby

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

test_config = 'test.yml'

count = 0
if File::exist?(test_config)
  File::delete(test_config)
end

File.open(test_config, "w") do |file|
  file << <<ENDDOC
# This is a comment
mask: "%show% - %season% - %epnumber% - %episode%"

shows:
  charmedaholic:
    url: Charmed
    customname: Charmed

  athf:
    customname: Aqua Teen Hunger Force
    url: AquaTeenHungerForce
    mask: "%show% - %season% - %epnumber% - %code% - %date% - %episode%"

  sponge:
    dateformat: "%m-%d-%Y"
    url: SpongeBobSquarePants
    mask: "%show% - %season% - %epnumber% - %date%"

  "knight rider 2008":
    url: KnightRider_2008
ENDDOC
end

tests = Hash.new
# season and episode are seperated by an 'x'
tests["colbert.report.2x1.avi"] = "Colbert Report - 2 - 01 - Nancy Grace.avi"
tests["colbert.report.2x10.avi"] = "Colbert Report - 2 - 10 - Robin Givhan.avi"
tests["colbert.report.2x100.avi"] = "Colbert Report - 2 - 100 - Bill Rhoden.avi"
tests["colbert.report.04x1.avi"] = "Colbert Report - 4 - 01 - Andrew Sullivan, Richard Freeman.avi"
tests["colbert.report.04x10.avi"] = "Colbert Report - 4 - 10 - Malcolm Gladwell, Andrew Young.avi"
tests["colbert.report.04x100.avi"] = "Colbert Report - 4 - 100 - David Carr.avi"

tests["colbert.report.4X2.avi"] = "Colbert Report - 4 - 02 - Chris Beam, Gary Rosen.avi"
tests["colbert.report.4X11.avi"] = "Colbert Report - 4 - 11 - Marie Wood, Jeb Corliss, Andrew McLean.avi"
tests["colbert.report.4X101.avi"] = "Colbert Report - 4 - 101 - Jason Bond, Kevin Costner.avi"
tests["colbert.report.04X3.avi"] = "Colbert Report - 4 - 03 - Gov. Mike Huckabee, Matt Taibbi.avi"
tests["colbert.report.04X12.avi"] = "Colbert Report - 4 - 12 - Debra Dickerson, Charles Nesson.avi"
tests["colbert.report.04X102.avi"] = "Colbert Report - 4 - 102 - Devin Gordon, Thomas Frank.avi"

# season and episode prefix
tests["colbert.report.s02e2.avi"] = "Colbert Report - 2 - 02 - Carl Bernstein.avi"
tests["colbert.report.s02e12.avi"] = "Colbert Report - 2 - 12 - Paul Begala.avi"
tests["colbert.report.s02e102.avi"] = "Colbert Report - 2 - 102 - Eli Pariser.avi"
tests["colbert.report.s2e3.avi"] = "Colbert Report - 2 - 03 - John Stossel.avi"
tests["colbert.report.s2e13.avi"] = "Colbert Report - 2 - 13 - Annie Duke.avi"
tests["colbert.report.s2e103.avi"] = "Colbert Report - 2 - 103 - Ramesh Ponnuru.avi"

tests["colbert.report.S02e4.avi"] = "Colbert Report - 2 - 04 - Ken Miller.avi"
tests["colbert.report.S02e14.avi"] = "Colbert Report - 2 - 14 - Dave Marash.avi"
tests["colbert.report.s02e104.avi"] = "Colbert Report - 2 - 104 - David Gergen.avi"
tests["colbert.report.S2e5.avi"] = "Colbert Report - 2 - 05 - George Stephanopoulos.avi"
tests["colbert.report.S2e15.avi"] = "Colbert Report - 2 - 15 - Emily Yoffe.avi"
tests["colbert.report.S2e105.avi"] = "Colbert Report - 2 - 105 - Morgan Spurlock.avi"

tests["colbert.report.s02E6.avi"] = "Colbert Report - 2 - 06 - Andrew Sullivan.avi"
tests["colbert.report.s02E16.avi"] = "Colbert Report - 2 - 16 - Gov. Christine Todd Whitman.avi"
tests["colbert.report.s02E106.avi"] = "Colbert Report - 2 - 106 - Neil Young.avi"
tests["colbert.report.s2E7.avi"] = "Colbert Report - 2 - 07 - Frank McCourt.avi"
tests["colbert.report.s2E17.avi"] = "Colbert Report - 2 - 17 - Barbara Boxer.avi"
tests["colbert.report.s2E107.avi"] = "Colbert Report - 2 - 107 - Geoffrey Nunberg.avi"

tests["colbert.report.S02E8.avi"] = "Colbert Report - 2 - 08 - Nina Totenberg.avi"
tests["colbert.report.S02E18.avi"] = "Colbert Report - 2 - 18 - R. James Woolsey.avi"
tests["colbert.report.S02E108.avi"] = "Colbert Report - 2 - 108 - Paul Krugman.avi"
tests["colbert.report.S2E9.avi"] = "Colbert Report - 2 - 09 - David Gregory.avi"
tests["colbert.report.S2E19.avi"] = "Colbert Report - 2 - 19 - Alan Dershowitz.avi"
tests["colbert.report.S2E109.avi"] = "Colbert Report - 2 - 109 - Gideon Yago.avi"

# season and episode are seperate tokens
tests["colbert.report.s03.e1.avi"] = "Colbert Report - 3 - 01 - Ethan Nadelmann.avi"
tests["colbert.report.s02.e20.avi"] = "Colbert Report - 2 - 20 - George Packer.avi"
tests["colbert.report.s02.e110.avi"] = "Colbert Report - 2 - 110 - Janna Levin.avi"
tests["colbert.report.s3.e2.avi"] = "Colbert Report - 3 - 02 - Jim Cramer.avi"
tests["colbert.report.s2.e21.avi"] = "Colbert Report - 2 - 21 - Lama Surya Das.avi"
tests["colbert.report.s2.e111.avi"] = "Colbert Report - 2 - 111 - Martin Short.avi"

tests["colbert.report.S03.e3.avi"] = "Colbert Report - 3 - 03 - David Kamp.avi"
tests["colbert.report.S02.e22.avi"] = "Colbert Report - 2 - 22 - Michael Eric Dyson.avi"
tests["colbert.report.s02.e112.avi"] = "Colbert Report - 2 - 112 - Toby Keith.avi"
tests["colbert.report.S3.e4.avi"] = "Colbert Report - 3 - 04 - Judy Woodruff.avi"
tests["colbert.report.S2.e23.avi"] = "Colbert Report - 2 - 23 - David Brooks.avi"
tests["colbert.report.S2.e113.avi"] = "Colbert Report - 2 - 113 - Ken Jennings.avi"

tests["colbert.report.s03.E5.avi"] = "Colbert Report - 3 - 05 - Alex Kuczynski.avi"
tests["colbert.report.s02.E24.avi"] = "Colbert Report - 2 - 24 - Tony Campolo.avi"
tests["colbert.report.s02.E114.avi"] = "Colbert Report - 2 - 114 - Bill Simmons.avi"
tests["colbert.report.s3.E6.avi"] = "Colbert Report - 3 - 06 - Dinesh D'Souza.avi"
tests["colbert.report.s2.E25.avi"] = "Colbert Report - 2 - 25 - Brett O'Donnell.avi"
tests["colbert.report.s2.E115.avi"] = "Colbert Report - 2 - 115 - Will Power.avi"

tests["colbert.report.S03.E7.avi"] = "Colbert Report - 3 - 07 - Richard Clarke.avi"
tests["colbert.report.S02.E26.avi"] = "Colbert Report - 2 - 26 - Arianna Huffington.avi"
tests["colbert.report.S02.E116.avi"] = "Colbert Report - 2 - 116 - Frank Rich.avi"
tests["colbert.report.S3.E8.avi"] = "Colbert Report - 3 - 08 - Bill O'Reilly.avi"
tests["colbert.report.S2.E27.avi"] = "Colbert Report - 2 - 27 - Jeffrey Sachs.avi"
tests["colbert.report.S2.E117.avi"] = "Colbert Report - 2 - 117 - James Carville.avi"

# all as one glob of numbers
tests["colbert.report.0408.avi"] = "Colbert Report - 4 - 08 - Lou Dobbs, David Levy.avi"
tests["colbert.report.0499.avi"] = "Colbert Report - 4 - 99 - Lucas Conley, The Apples in Stereo.avi"
tests["colbert.report.409.avi"] = "Colbert Report - 4 - 09 - Allan Sloan, Eric Weiner.avi"


# special cases
tests["knight.rider.2008.0101.avi"] = "Knight Rider 2008 - 1 - 01 - A Knight in Shining Armor.avi"
tests["knight.rider.2008.104.avi"] = "Knight Rider 2008 - 1 - 04 - A Hard Day's Knight.avi"
tests["sealab.2021.0201.avi"] = "Sealab 2021 - 2 - 01 - Der Dieb.avi"
tests["sealab.2021.205.avi"] = "Sealab 2021 - 2 - 05 - Legend of Baggy Pants.avi"
tests["the.4400.0201.avi"] = "The 4400 - 2 - 01 - Wake-Up Call (1).avi"
tests["the.4400.205.avi"] = "The 4400 - 2 - 05 - Suffer The Children.avi"
tests["the.oblongs.1x11.avi"] = "The Oblongs - 1 - 11 - Bucketheads.avi"
tests["mork.and.mindy.1x21.avi"] = "Mork And Mindy - 1 - 21 - Mork's Night Out.avi"

# custom renaming
tests["charmedaholic.1x1.avi"] = "Charmed - 1 - 01 - Something Wicca This Way Comes.avi"
tests["athf.1x18.avi"] = "Aqua Teen Hunger Force - 1 - 18 - 118 - 29-Dec-02 - Cybernetic Ghost Of Christmas Past From The Future.avi"
tests["Sponge.4x18.avi"] = "Sponge - 4 - 18 - 05-05-2006.avi"

tests.each do |test, expected|
  system("touch " + test)
end

`tv_renamer -c #{test_config}`

tests.each do |test, expected|
  if !File::exist?(expected)
    count += 1
    puts "#{test} failed to rename to #{expected}"
  else
    File::delete(expected)
  end
end

Dir['*.{avi,wmv,divx,mpg,mpeg,xvid,mp4,mkv}'].each do |file|
  puts "Unexpected file #{file}"
  File::delete(file)
end

tests.each do |test, expected|
  newtest = test.dup
  newtest.gsub!('.', ' ')
  newtest[newtest.rindex(' ')] = '.'
  system("touch \"" + newtest + "\"")
end

`tv_renamer -c #{test_config}`

tests.each do |test, expected|
  newtest = test.dup
  newtest.gsub!('.', ' ')
  newtest[newtest.rindex(' ')] = '.'
  if !File::exist?(expected)
    count += 1
    print  newtest + " failed to rename properly\n"
  else
    File::delete(expected)
  end
end

Dir['*.{avi,wmv,divx,mpg,mpeg,xvid,mp4,mkv}'].each do |file|
  puts "Unexpected file #{file}"
  File::delete(file)
end

if count == 0
  print "All #{tests.length * 2} tests passed!\n"
else
  print "#{count} tests of #{tests.length * 2} failed\n"
end


File::delete(test_config)
