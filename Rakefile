# coding: utf-8
require 'rubygems'
require 'rake/clean'
PWD = File.join(File.dirname(__FILE__))

# Compiled AppleScript scripts
CLEAN.include('*.scpt', '*.scptd')
CLOBBER.include('Documentation')

SRC = FileList['*.applescript']
OBJ = SRC.ext('scpt')

task :default => ["build"]

rule '.scpt' => '.applescript' do |t|
	sh "osacompile -x -o '#{t.name}' '#{t.source}'" # do |ok,res|
end

desc "Build project."
task :build do
	app = 'KeychainCSV.app'
	sh "osacompile -x -o '#{app}' 'CSVKeychain.applescript'"
end

desc "Build the documentation using HeaderDoc"
task :doc do
	# Set LANG to get rid of warnings about missing default encoding
	sh "env LANG=en_US.UTF-8 headerdoc2html -q -o Documentation CSVKeychain.applescript"
	sh "env LANG=en_US.UTF-8 gatherheaderdoc Documentation"
end
