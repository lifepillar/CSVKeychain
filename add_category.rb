#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'csv'
require 'optparse'

# Position of fields in the CSV output by CSVKeychain
URL      = 0
USERNAME = 1
PASSWORD = 2
TITLE    = 3
NOTES    = 4
CREATED  = 5
MODIFIED = 6
KIND     = 7
TYPE     = 8
DOMAIN   = 9
AUTHTYPE = 10
CLASS    = 11
CREATOR  = 12

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: add_category <path>"

  opts.on("-o", "--output PATH", "Output file") do |o|
    options[:out] = o
  end
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

input_file = ARGV.first

if input_file.nil?
  puts "Please specify the path of a CSV file."
  exit(1)
end

outfile = options.fetch(:out, File.join(File.dirname(input_file), File.basename(input_file, '.csv') + '-out.csv'))
out = CSV.open(outfile, "wb")
out << ["Where","Account","Password","Label","Comment","Created","Modified","Kind","Type","Domain","AuthType","Class","Creator","Category"]

CSV.foreach(input_file, :headers => true) do |row|
  if row[KIND] =~ /secure\s+note/i or row[TYPE] == 'note'
    group = 'Notes'
  elsif row[KIND] =~ /network|802\.1|airport|handoff|sharing/i or row[URL] =~ /^.?(afp|ftp|smb|ssh|teln|vnc)/i
    group = 'Network'
  elsif row[CLASS] == 'inet' and row[URL] =~ /^.?(pop|smtp|imap|mail)/i
    group = 'EMail'
  elsif row[URL] =~ /:\/\//
    group = 'Internet'
  else
    group = 'General'
  end
  row << group
  out << row
end

out.close
puts "Done!"
