#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'csv'
require 'optparse'

# Position of fields in the CSV output by CSVKeychain
WHERE    = 0
ACCOUNT  = 1
PASSWORD = 2
LABEL    = 3
COMMENT  = 4
CREATED  = 5
MODIFIED = 6
KIND     = 7
TYPE     = 8
DOMAIN   = 9
AUTHTYPE = 10
CLASS    = 11
CREATOR  = 12

COLORS = { :red => 31, :green => 32, :yellow => 33, :blue => 34 }

def color(s, col = nil)
  return s if col.nil?
  return "\e[#{COLORS[col]}m#{s}\e[0m"
end

def compare_items(x,y)
  if x[CLASS] != y[CLASS]
    return x[CLASS] <=> y[CLASS]
  end
  # Same class
  if x[CLASS] == 'inet'
    return x[ACCOUNT] != y[ACCOUNT] ? x[ACCOUNT] <=> y[ACCOUNT] : (x[WHERE] != y[WHERE] ? x[WHERE] <=> y[WHERE] : x[AUTHTYPE] <=> y[AUTHTYPE])
  end
  # genp
  return x[ACCOUNT] != y[ACCOUNT] ? x[ACCOUNT] <=> y[ACCOUNT] : x[WHERE] <=> y[WHERE]
end

def mask_password(pwd)
  pwd[0..[2,pwd.length].min] + '********'
end

def please_choose(r1, r2)
  pwd1 = mask_password(r1[PASSWORD])
  pwd2 = mask_password(r2[PASSWORD])
  pad  = [r1[LABEL], r1[ACCOUNT], r1[WHERE], r1[CREATED], r1[MODIFIED], r1[PASSWORD]].collect { |i| i.length }.max + 1
  pad2 = [r2[LABEL], r2[ACCOUNT], r2[WHERE], r2[CREATED], r2[MODIFIED], r2[PASSWORD]].collect { |i| i.length }.max + 1

  sep       = "---------|-"                          + ('-' * pad)                         + "|" + ('-' * pad2)
  name      = "    Name | #{r1[LABEL]}"              + (' ' * (pad - r1[LABEL].length))    + "| #{r2[LABEL]}"
  account   = " Account | #{r1[ACCOUNT]}"            + (' ' * (pad - r1[ACCOUNT].length))  + "| #{r2[ACCOUNT]}"
  where     = "   Where | #{r1[WHERE]}"              + (' ' * (pad - r1[WHERE].length))    + "| #{r2[WHERE]}"
  created   = " Created | #{r1[CREATED]}"            + (' ' * (pad - r1[CREATED].length))  + "| #{r2[CREATED]}"
  modified  = "Modified | #{r1[MODIFIED]}"           + (' ' * (pad - r1[MODIFIED].length)) + "| #{r2[MODIFIED]}"
  password  = "Password | #{pwd1}"                   + (' ' * (pad - pwd1.length))         + "| #{pwd2}"
  unless (r1[MODIFIED].nil? or r1[MODIFIED].empty? or r2[MODIFIED].nil? or r2[MODIFIED].empty?)
    if (r1[MODIFIED] > r2[MODIFIED])
      newer = "         | " + color('NEWER', :green) + (' ' * (pad - 5))                   + "| OLDER"
    elsif (r1[MODIFIED] < r2[MODIFIED])
      newer = "         | OLDER"           + (' ' * (pad - 5))                   + "| " + color('NEWER', :green)
    else
      newer = ""
    end
  end

  puts sep
  puts color(name,     r1[LABEL] == r2[LABEL]             ? nil : :red)
  puts color(account,  r1[ACCOUNT] == r2[ACCOUNT]         ? nil : :red)
  puts color(where,    r1[WHERE] == r2[WHERE]             ? nil : :red)
  puts color(created,  r1[CREATED] == r2[CREATED]         ? nil : :red)
  puts color(modified, r1[MODIFIED] == r2[MODIFIED]       ? nil : :red)
  puts color(password, r1[PASSWORD] == r2[PASSWORD]       ? nil : :red)
  puts sep
  puts newer
  choice = nil
  loop do
    print "Choose ([l]eft/[r]ight/[b]oth/[n]one/[c]ancel): "
    choice = $stdin.gets
    break if choice =~ /^\s*[bclnr]/
  end
  case choice
  when /^\s*l/
    puts color("Keeping left", :yellow)
    return [r1]
  when /^\s*r/
    puts color("Keeping right", :yellow)
    return [r2]
  when /^\s*b/
    puts color("Keeping both", :yellow)
    return [r1,r2]
  when /^\s*n/
    puts color("Skipping both", :yellow)
    return []
  when /^\s*c/
    puts "Canceled."
    exit(0)
  else
    puts "We shouldn't have gotten this far."
    exit(1)
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = <<HERE
  Usage: merge_csv <path> <path>

  Specify at most one among -a, -k, -i, -O.

  The default behaviour to deal with matching items is to keep
  the most recent item, or both if some timestamp is missing.

HERE

  opts.on("-a", "--ask", "Ask only when timestamps are missing") do |o|
    options[:ask] = o
  end
  opts.on("-h", "--help", "Print this help") do
    puts opts
    exit
  end
  opts.on("-k", "--keep", "Keep all duplicates") do |o|
    options[:keep] = o
  end
  opts.on("-i", "--interactive", "Ask what to do with each duplicate") do |o|
    options[:interactive] = o
  end
  opts.on("-O", "--overwrite", "Overwrite the second CSV with items from the first") do |o|
    options[:overwrite] = o
  end
  opts.on("-o", "--output PATH", "Output file") do |o|
    options[:out] = o
  end
end.parse!

path1 = ARGV[0]
path2 = ARGV[1]

if path1.nil? or path2.nil?
  puts "Please specify the paths of the two CSV files to be merged."
  exit(1)
end

csv1 = CSV.read(path1)
csv2 = CSV.read(path2)
csv1.sort! { |x,y| compare_items(x,y) }
csv2.sort! { |x,y| compare_items(x,y) }

outfile = options.fetch(:out, 'merged.csv')
out = CSV.open(outfile, "wb")
out << csv1[0] # Header

i = 1 # Skip header
j = 1 # Ditto
m = csv1.length
n = csv2.length
p = [m,n].min
while i < p
  r1 = csv1[i]
  r2 = csv2[j]
  case compare_items(r1, r2)
  when -1
    out << r1
    i += 1
  when 1
    out << r2
    j += 1
  when 0 # Matching items
    if options.fetch(:keep, false)
      out << r1
      out << r2
    elsif options.fetch(:overwrite, false)
      out << r1
    elsif options.fetch(:interactive, false) or (options.fetch(:ask, false) and (r1[MODIFIED].nil? or r1[MODIFIED].empty? or r2[MODIFIED].nil? or r2[MODIFIED].empty?))
      please_choose(r1, r2).each { |r| out << r }
    else
      # Default behaviour is to keep the most recent item, or both if some timestamp is missing
      if r1[MODIFIED].nil? or r1[MODIFIED].empty? or r2[MODIFIED].nil? or r2[MODIFIED].empty?
        out << r1
        out << r2
      else
        out << (r1[MODIFIED] > r2[MODIFIED] ? r1 : r2)
      end
    end
    i += 1
    j += 1
  else
    puts "WARN: skipping items at rows #{i} and #{j}"
    i += 1
    j += 1
  end
end

# Copy remaining records
while i < m
  out << csv1[i]
  i += 1
end
while j < n
  out << csv2[j]
  j += 1
end

out.close
puts "Done!"
