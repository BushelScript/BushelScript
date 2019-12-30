#!/usr/bin/env ruby

input = File.foreach(ENV['SCRIPT_INPUT_FILE_0'])
  .map do |line|
    next '' if line =~ /^\s*(#.*)?$/
    line.split(/\s*->\s*/)
  end
  .filter { |line| !line.empty? }

copied_count = 0

input.each do |line|
  in_spec, out_spec = line[0].chomp, line[1].chomp
    
  in_file = File.join(ENV['SWIFT_PACKAGE_DEPS_DIR'], in_spec)
  out_file = File.join(ENV['BUILT_PRODUCTS_DIR'], ENV['UNLOCALIZED_RESOURCES_FOLDER_PATH'], out_spec)
  
  # `source ~/.bash_profile && osashow "#{in_file.to_s + ' <-> ' + out_file.to_s}"`
    
  if File.exists?(out_file)
    puts "Destination license file #{out_file} already exists, ignoring"
  elsif !File.exists?(in_file)
    puts "warning: Input license file #{in_file} (generated from “#{line[0]}” in #{ENV['SCRIPT_INPUT_FILE_0']}) does not exist, ignoring"
  else
    `cp -v '#{in_file}' '#{out_file}'`
    copied_count += 1
  end
end

puts "Copied #{copied_count} licenses of #{input.count} to #{File.join(ENV['BUILT_PRODUCTS_DIR'], ENV['UNLOCALIZED_RESOURCES_FOLDER_PATH'])}"
