#!/usr/bin/env ruby

require 'fileutils'

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

$test_config = 'test.yml'

if File::exist?($test_config)
  File::delete($test_config)
end

File.open($test_config, "w") do |file|
  file << <<ENDDOC
# This is a comment
global:
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

$tests = Hash.new
# season and episode are seperated by an 'x'
$tests["colbert.report.2x1"] = "Colbert Report - 2 - 01 - Nancy Grace"
$tests["colbert.report.2x10"] = "Colbert Report - 2 - 10 - Robin Givhan"
$tests["colbert.report.2x100"] = "Colbert Report - 2 - 100 - Bill Rhoden"
$tests["colbert.report.04x1"] = "Colbert Report - 4 - 01 - Andrew Sullivan, Richard Freeman"
$tests["colbert.report.04x10"] = "Colbert Report - 4 - 10 - Malcolm Gladwell, Andrew Young"
$tests["colbert.report.04x100"] = "Colbert Report - 4 - 100 - David Carr"

$tests["colbert.report.4X2"] = "Colbert Report - 4 - 02 - Chris Beam, Gary Rosen"
$tests["colbert.report.4X11"] = "Colbert Report - 4 - 11 - Marie Wood, Jeb Corliss, Andrew McLean"
$tests["colbert.report.4X101"] = "Colbert Report - 4 - 101 - Jason Bond, Kevin Costner"
$tests["colbert.report.04X3"] = "Colbert Report - 4 - 03 - Gov. Mike Huckabee, Matt Taibbi"
$tests["colbert.report.04X12"] = "Colbert Report - 4 - 12 - Debra Dickerson, Charles Nesson"
$tests["colbert.report.04X102"] = "Colbert Report - 4 - 102 - Devin Gordon, Thomas Frank"

# season and episode prefix
$tests["colbert.report.s02e2"] = "Colbert Report - 2 - 02 - Carl Bernstein"
$tests["colbert.report.s02e12"] = "Colbert Report - 2 - 12 - Paul Begala"
$tests["colbert.report.s02e102"] = "Colbert Report - 2 - 102 - Eli Pariser"
$tests["colbert.report.s2e3"] = "Colbert Report - 2 - 03 - John Stossel"
$tests["colbert.report.s2e13"] = "Colbert Report - 2 - 13 - Annie Duke"
$tests["colbert.report.s2e103"] = "Colbert Report - 2 - 103 - Ramesh Ponnuru"

$tests["colbert.report.S02e4"] = "Colbert Report - 2 - 04 - Ken Miller"
$tests["colbert.report.S02e14"] = "Colbert Report - 2 - 14 - Dave Marash"
$tests["colbert.report.s02e104"] = "Colbert Report - 2 - 104 - David Gergen"
$tests["colbert.report.S2e5"] = "Colbert Report - 2 - 05 - George Stephanopoulos"
$tests["colbert.report.S2e15"] = "Colbert Report - 2 - 15 - Emily Yoffe"
$tests["colbert.report.S2e105"] = "Colbert Report - 2 - 105 - Morgan Spurlock"

$tests["colbert.report.s02E6"] = "Colbert Report - 2 - 06 - Andrew Sullivan"
$tests["colbert.report.s02E16"] = "Colbert Report - 2 - 16 - Gov. Christine Todd Whitman"
$tests["colbert.report.s02E106"] = "Colbert Report - 2 - 106 - Neil Young"
$tests["colbert.report.s2E7"] = "Colbert Report - 2 - 07 - Frank McCourt"
$tests["colbert.report.s2E17"] = "Colbert Report - 2 - 17 - Barbara Boxer"
$tests["colbert.report.s2E107"] = "Colbert Report - 2 - 107 - Geoffrey Nunberg"

$tests["colbert.report.S02E8"] = "Colbert Report - 2 - 08 - Nina Totenberg"
$tests["colbert.report.S02E18"] = "Colbert Report - 2 - 18 - R. James Woolsey"
$tests["colbert.report.S02E108"] = "Colbert Report - 2 - 108 - Paul Krugman"
$tests["colbert.report.S2E9"] = "Colbert Report - 2 - 09 - David Gregory"
$tests["colbert.report.S2E19"] = "Colbert Report - 2 - 19 - Alan Dershowitz"
$tests["colbert.report.S2E109"] = "Colbert Report - 2 - 109 - Gideon Yago"

# season and episode are seperate tokens
$tests["colbert.report.s03.e1"] = "Colbert Report - 3 - 01 - Ethan Nadelmann"
$tests["colbert.report.s02.e20"] = "Colbert Report - 2 - 20 - George Packer"
$tests["colbert.report.s02.e110"] = "Colbert Report - 2 - 110 - Janna Levin"
$tests["colbert.report.s3.e2"] = "Colbert Report - 3 - 02 - Jim Cramer"
$tests["colbert.report.s2.e21"] = "Colbert Report - 2 - 21 - Lama Surya Das"
$tests["colbert.report.s2.e111"] = "Colbert Report - 2 - 111 - Martin Short"

$tests["colbert.report.S03.e3"] = "Colbert Report - 3 - 03 - David Kamp"
$tests["colbert.report.S02.e22"] = "Colbert Report - 2 - 22 - Michael Eric Dyson"
$tests["colbert.report.s02.e112"] = "Colbert Report - 2 - 112 - Toby Keith"
$tests["colbert.report.S3.e4"] = "Colbert Report - 3 - 04 - Judy Woodruff"
$tests["colbert.report.S2.e23"] = "Colbert Report - 2 - 23 - David Brooks"
$tests["colbert.report.S2.e113"] = "Colbert Report - 2 - 113 - Ken Jennings"

$tests["colbert.report.s03.E5"] = "Colbert Report - 3 - 05 - Alex Kuczynski"
$tests["colbert.report.s02.E24"] = "Colbert Report - 2 - 24 - Tony Campolo"
$tests["colbert.report.s02.E114"] = "Colbert Report - 2 - 114 - Bill Simmons"
$tests["colbert.report.s3.E6"] = "Colbert Report - 3 - 06 - Dinesh D'Souza"
$tests["colbert.report.s2.E25"] = "Colbert Report - 2 - 25 - Brett O'Donnell"
$tests["colbert.report.s2.E115"] = "Colbert Report - 2 - 115 - Will Power"

$tests["colbert.report.S03.E7"] = "Colbert Report - 3 - 07 - Richard Clarke"
$tests["colbert.report.S02.E26"] = "Colbert Report - 2 - 26 - Arianna Huffington"
$tests["colbert.report.S02.E116"] = "Colbert Report - 2 - 116 - Frank Rich"
$tests["colbert.report.S3.E8"] = "Colbert Report - 3 - 08 - Bill O'Reilly"
$tests["colbert.report.S2.E27"] = "Colbert Report - 2 - 27 - Jeffrey Sachs"
$tests["colbert.report.S2.E117"] = "Colbert Report - 2 - 117 - James Carville"

# all as one glob of numbers
$tests["colbert.report.0408"] = "Colbert Report - 4 - 08 - Lou Dobbs, David Levy"
$tests["colbert.report.0499"] = "Colbert Report - 4 - 99 - Lucas Conley, The Apples in Stereo"
$tests["colbert.report.409"] = "Colbert Report - 4 - 09 - Allan Sloan, Eric Weiner"


# special cases
$tests["knight.rider.2008.0101"] = "Knight Rider 2008 - 1 - 01 - A Knight in Shining Armor"
$tests["knight.rider.2008.104"] = "Knight Rider 2008 - 1 - 04 - A Hard Day's Knight"
$tests["sealab.2021.0201"] = "Sealab 2021 - 2 - 01 - Der Dieb"
$tests["sealab.2021.205"] = "Sealab 2021 - 2 - 05 - Legend of Baggy Pants"
$tests["the.4400.0201"] = "The 4400 - 2 - 01 - Wake-Up Call (1)"
$tests["the.4400.205"] = "The 4400 - 2 - 05 - Suffer The Children"
$tests["the.oblongs.1x11"] = "The Oblongs - 1 - 11 - Bucketheads"
$tests["mork.and.mindy.1x21"] = "Mork And Mindy - 1 - 21 - Mork's Night Out"

# custom renaming
$tests["charmedaholic.1x1"] = "Charmed - 1 - 01 - Something Wicca This Way Comes"
$tests["athf.1x18"] = "Aqua Teen Hunger Force - 1 - 18 - 118 - 29-Dec-02 - Cybernetic Ghost Of Christmas Past From The Future"
$tests["Sponge.4x18"] = "Sponge - 4 - 18 - 05-05-2006"

$failures = 0
$verbose = true

def run_test(substitution)
  $tests.each do |from, to|
    FileUtils::touch("#{from.gsub('.', substitution)}.avi")
  end
  
  cmd = "tv_renamer -c #{$test_config}"
  unless $verbose
    `#{cmd}`
  else
    system cmd
  end
  
  $tests.each do |from, to|
    from = "#{from.gsub('.', substitution)}.avi"
    
    to = "#{to}.avi"
    if !File::exist?(to)
      $failures += 1
      print "#{from} failed to #{to} rename properly\n"
    else
      File::delete(to)
    end
  end

  Dir['*.{avi,wmv,divx,mpg,mpeg,xvid,mp4,mkv}'].each do |file|
#     puts "Unexpected file #{file}"
    File::delete(file)
  end
end

['.', ' '].each do |separator|
  run_test separator
end

if $failures == 0
  print "All #{$tests.length * 2} tests passed!\n"
else
  print "#{$failures} tests of #{$tests.length * 2} failed\n"
end


File::delete($test_config)
