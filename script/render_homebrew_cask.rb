#!/usr/bin/env ruby
require 'erb'
require 'fileutils'

version, sha256, owner, repo, output_path = ARGV

abort "usage: ./script/render_homebrew_cask.rb <version> <sha256> <owner> <repo> <output-path>" unless output_path

root = File.expand_path('..', __dir__)
template_path = File.join(root, 'Homebrew', 'Casks', 'keytok.rb.erb')
template = ERB.new(File.read(template_path), trim_mode: '-')

rendered = template.result_with_hash(
  version: version,
  sha256: sha256,
  owner: owner,
  repo: repo
)

FileUtils.mkdir_p(File.dirname(output_path))
File.write(output_path, rendered)
