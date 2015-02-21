# encoding: utf-8

require File.expand_path('../lib/tv_renamer/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name        = 'tv_renamer'
  spec.version     = TvRenamer::VERSION
  spec.date        = '2015-02-20'
  spec.summary     = "TV Show Renamer"
  spec.description = "A tool to rename TV shows using data from epguides.com"
  spec.authors     = ["Kevin Adler"]
  spec.email       = 'zeke@zekesdominion.com'
  spec.homepage    = 'https://github.com/adler187/tvrenamer'
  spec.license     = 'GPL-2'
  
  spec.required_ruby_version = '>= 2.0'
  
  spec.add_runtime_dependency 'nokogiri', '~> 1.0'
  
  
  spec.files       = %w(LICENSE README.md)
  spec.files      += Dir.glob("bin/**/*")
  spec.files      += Dir.glob("lib/**/*")
  spec.files      += Dir.glob("test/**/*.rb")
  
  spec.executables = %w( tv_renamer )
end