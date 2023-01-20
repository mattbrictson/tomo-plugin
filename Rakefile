require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

RuboCop::RakeTask.new

task default: %i[test rubocop]

# == "rake release" enhancements ==============================================

Rake::Task["release"].enhance do
  puts "Don't forget to publish the release on GitHub!"
  system "open https://github.com/mattbrictson/tomo-plugin/releases"
end

task :disable_overcommit do
  ENV["OVERCOMMIT_DISABLE"] = "1"
end

Rake::Task[:build].enhance [:disable_overcommit]

task :verify_gemspec_files do
  git_files = `git ls-files -z`.split("\x0")
  gemspec_files = Gem::Specification.load("example.gemspec").files.sort
  ignored_by_git = gemspec_files - git_files
  next if ignored_by_git.empty?

  raise <<~ERROR

    The `spec.files` specified in example.gemspec include the
    following files that are being ignored by git. Did you forget to add them
    to the repo? If not, you may need to delete these files or modify the
    gemspec to ensure that they are not included in the gem by mistake:

    #{ignored_by_git.join("\n").gsub(/^/, '  ')}

  ERROR
end

Rake::Task[:build].enhance [:verify_gemspec_files]

# == "rake bump" tasks ========================================================

task bump: %w[bump:bundler bump:ruby bump:year]

namespace :bump do
  task :bundler do
    version = Gem.latest_version_for("bundler").to_s
    replace_in_file "Gemfile.lock", /^BUNDLED WITH\n\s+(\d\S+)$/ => version
  end

  task :ruby do
    lowest_minor = RubyVersions.lowest_supported_minor
    latest = RubyVersions.latest
    latest_patches = RubyVersions.latest_supported_patches

    replace_in_file "example.gemspec", /ruby_version = .*">= (.*)"/ => lowest_minor
    replace_in_file ".rubocop.yml", /TargetRubyVersion: (.*)/ => lowest_minor
    replace_in_file ".semaphore/semaphore.yml", /SEM_RUBY:-([\d.]+)/ => latest
    replace_in_file ".semaphore/semaphore.yml", /values: (\[.+\])/ => latest_patches.inspect
    replace_in_file ".github/workflows/ci.yml", /ruby-version: "([\d.]+)"/ => latest
    replace_in_file ".github/workflows/ci.yml", /ruby: (\[.+\])/ => latest_patches.inspect
  end

  task :year do
    replace_in_file "LICENSE.txt", /\(c\) (\d+)/ => Date.today.year.to_s
  end
end

require "date"
require "open-uri"
require "yaml"

def replace_in_file(path, replacements)
  contents = File.read(path)
  orig_contents = contents.dup
  replacements.each do |regexp, text|
    raise "Can't find #{regexp} in #{path}" unless regexp.match?(contents)

    contents.gsub!(regexp) do |match|
      match[regexp, 1] = text
      match
    end
  end
  File.write(path, contents) if contents != orig_contents
end

module RubyVersions
  class << self
    def lowest_supported_minor
      latest_supported_patches.first[/\d+\.\d+/]
    end

    def latest
      latest_supported_patches.last
    end

    def latest_supported_patches
      patches = versions.values_at(:stable, :security_maintenance, :eol).compact.flatten
      patches.map { |p| Gem::Version.new(p) }.sort.map(&:to_s)
    end

    private

    def versions
      @_versions ||= begin
        yaml = URI.open("https://raw.githubusercontent.com/ruby/www.ruby-lang.org/HEAD/_data/downloads.yml")
        YAML.safe_load(yaml, symbolize_names: true)
      end
    end
  end
end
