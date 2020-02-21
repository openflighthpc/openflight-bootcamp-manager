#!/usr/bin/env ruby

require 'yaml'
require 'erb'
require 'fileutils'

appdir = '/root/openflight-bootcamp-manager'

index_template = appdir + '/templates/index.html.erb'
cluster_template = appdir + '/templates/cluster.html.erb'
vnc_template = appdir + '/templates/vnc.html.erb'

name = ENV['NAME'] # Name of the bootcamp session
outdir = ENV['WEBROOT']
sessiondir = ENV['SESSIONDIR']
count = ENV['COUNT']

clustername_prefix = 'group'

# Load in all cluster yaml files into one big hash
files = Dir[sessiondir + '/*']
files.delete(sessiondir + '/session.yaml')
yamls = files.map { |f| YAML.load_file(f) }
@bootcamp = files.each_with_object({}).with_index { |(e, hash), i| hash[File.basename(e.gsub('.yaml', ''))] = yamls[i] }

# Generate index
index_out = outdir + '/index.html'
index_render = ERB.new(File.read(index_template))
File.open(index_out, 'w') do |f|
  f.write index_render.result()
end

# Generate cluster pages
(1..count).each do |val|
  clustername = clustername_prefix + val
  cluster_out = outdir + '/' + clustername + '.html'
  cluster_render = ERB.new(File.read(cluster_template))

  # Load in cluster information
  # @cluster = YAML.load_file(sessiondir + clustername + '.yaml')
  @cluster = @bootcamp[clustername]
  File.open(cluster_out, 'w') do |f|
    f.write cluster_render.result()
  end

  # Generate VNC pages
  cluster_dir = outdir + clustername
  FileUtils.mkdir_p cluster_dir
  @cluster['vnc'].each do |type, info|
    vnc_out = cluster_dir + '/' + type + '.html'
    vnc_render = ERB.new(File.read(vnc_template))
    File.open(vnc_out, 'w') do |f|
      f.write vnc_render.result()
    end
  end
end

