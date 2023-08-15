#!/usr/bin/env ruby

require "bundler/inline"
require "fileutils"
require "io/console"
require "open3"
require "shellwords"

def main # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  assert_git_repo!
  git_meta = read_git_data

  plugin_name = ask("Plugin name?", default: git_meta[:origin_repo_name].sub(/^tomo-plugin-/, ""))
  plugin_name.sub!(/^tomo-plugin-/, "")
  gem_name = "tomo-plugin-#{plugin_name}"
  gem_summary = ask(
    "Gem summary (< 60 chars)?", default: "#{plugin_name} tasks for tomo"
  )
  author_email = ask("Author email?", default: git_meta[:user_email])
  author_name = ask("Author name?", default: git_meta[:user_name])
  github_repo = ask("GitHub repository?", default: git_meta[:origin_repo_path])

  created_labels = \
    if gh_present?
      puts
      puts "I would like to use the `gh` executable to create labels in your repo."
      puts "These labels will be used to generate nice-looking release notes."
      puts
      if ask_yes_or_no("Create GitHub labels using `gh`?", default: "Y")
        create_labels(github_repo)
        true
      end
    end

  replace_in_file(".github/dependabot.yml", /\s+labels:\n\s+-.*$/ => "") unless created_labels

  git "mv", ".github/workflows/release-drafter.yml.dist", ".github/workflows/release-drafter.yml"

  FileUtils.mkdir_p "lib/#{as_path(gem_name)}"
  FileUtils.mkdir_p "test/#{as_path(gem_name)}"

  ensure_executable "bin/console"
  ensure_executable "bin/setup"

  replace_in_file "LICENSE.txt",
                  "Example Owner" => author_name

  replace_in_file "Rakefile",
                  "example.gemspec" => "#{gem_name}.gemspec",
                  "mattbrictson/tomo-plugin" => github_repo

  replace_in_file "README.md",
                  "mattbrictson/tomo-plugin" => github_repo,
                  "example" => plugin_name,
                  "plugin_name" => plugin_name.tr("-", "_"),
                  "replace_with_gem_name" => gem_name,
                  /\A.*<!-- END FRONT MATTER -->\n+/m => ""

  replace_in_file "CHANGELOG.md",
                  "mattbrictson/tomo-plugin" => github_repo

  replace_in_file "CODE_OF_CONDUCT.md",
                  "owner@example.com" => author_email

  replace_in_file "bin/console", "tomo/plugin/example" => as_path(gem_name)

  replace_in_file "example.gemspec",
                  "mattbrictson/tomo-plugin" => github_repo,
                  '"Example Owner"' => author_name.inspect,
                  '"owner@example.com"' => author_email.inspect,
                  '"example"' => gem_name.inspect,
                  "example/version" => "#{as_path(plugin_name)}/version",
                  "Example::VERSION" => "#{as_module(plugin_name)}::VERSION",
                  /summary\s*=\s*("")/ => gem_summary.inspect

  git "mv", "example.gemspec", "#{gem_name}.gemspec"

  replace_in_file "lib/tomo/plugin/example.rb",
                  "example" => as_path(plugin_name).sub(%r{^.*/}, ""),
                  "plugin_name" => plugin_name.tr("-", "_"),
                  "Example" => as_module(plugin_name)

  git "mv", "lib/tomo/plugin/example.rb", "lib/#{as_path(gem_name)}.rb"

  replace_in_file "lib/tomo/plugin/example/version.rb", <<~MODULE => ""
    module Tomo
      module Plugin
      end
    end

  MODULE

  %w[helpers tasks version].each do |file|
    replace_in_file "lib/tomo/plugin/example/#{file}.rb",
                    "Example" => as_module(plugin_name),
                    "example" => plugin_name
    git "mv", "lib/tomo/plugin/example/#{file}.rb", "lib/#{as_path(gem_name)}/#{file}.rb"
  end

  reindent_module "lib/#{as_path(gem_name)}.rb"
  reindent_module "lib/#{as_path(gem_name)}/version.rb"

  replace_in_file "test/tomo/plugin/example_test.rb",
                  "Example" => as_module(plugin_name)
  git "mv", "test/tomo/plugin/example_test.rb", "test/#{as_path(gem_name)}_test.rb"

  %w[helpers_test tasks_test].each do |file|
    replace_in_file "test/tomo/plugin/example/#{file}.rb",
                    "Example" => as_module(plugin_name)
    replace_in_file "test/tomo/plugin/example/#{file}.rb",
                    "example" => plugin_name
    git "mv", "test/tomo/plugin/example/#{file}.rb", "test/#{as_path(gem_name)}/#{file}.rb"
  end

  replace_in_file "test/test_helper.rb",
                  'require "tomo/plugin/example"' =>
                    %Q(require "#{as_path(gem_name)}")

  git "rm", "rename_template.rb"

  puts <<~MESSAGE

    All set!

    The project has been renamed to "#{gem_name}".
    Review the changes and then run:

      git commit && git push

  MESSAGE
end

def assert_git_repo!
  return if File.file?(".git/config")

  warn("This doesn't appear to be a git repo. Can't continue. :(")
  exit(1)
end

def git(*args)
  sh! "git", *args
end

def ensure_executable(path)
  return if File.executable?(path)

  FileUtils.chmod 0o755, path
  git "add", path
end

def sh!(*args)
  puts ">>>> #{args.join(' ')}"
  stdout, status = Open3.capture2(*args)
  raise("Failed to execute: #{args.join(' ')}") unless status.success?

  stdout
end

def remove_line(file, pattern)
  text = File.read(file)
  text = text.lines.filter.grep_v(pattern).join
  File.write(file, text)
  git "add", file
end

def ask(question, default: nil, echo: true)
  prompt = "#{question} "
  prompt << "[#{default}] " unless default.nil?
  print prompt
  answer = if echo
             $stdin.gets.chomp
           else
             $stdin.noecho(&:gets).tap { $stdout.print "\n" }.chomp
           end
  answer.to_s.strip.empty? ? default : answer
end

def ask_yes_or_no(question, default: "N")
  default = default == "Y" ? "Y/n" : "y/N"
  answer = ask(question, default: default)

  answer != "y/N" && answer.match?(/^y/i)
end

def read_git_data
  return {} unless git("remote", "-v").match?(/^origin/)

  origin_url = git("remote", "get-url", "origin").chomp
  origin_repo_path = origin_url[%r{[:/]([^/]+/[^/]+?)(?:\.git)?$}, 1]

  {
    origin_repo_name: origin_repo_path&.split("/")&.last,
    origin_repo_path: origin_repo_path,
    user_email: git("config", "user.email").chomp,
    user_name: git("config", "user.name").chomp
  }
end

def replace_in_file(path, replacements)
  contents = File.read(path)
  replacements.each do |regexp, text|
    contents.gsub!(regexp) do |match|
      next text if Regexp.last_match(1).nil?

      match[regexp, 1] = text
      match
    end
  end

  File.write(path, contents)
  git "add", path
end

def as_path(gem_name)
  gem_name.tr("-", "/")
end

def as_module(gem_name)
  parts = gem_name.split("-")
  parts.map do |part|
    part.gsub(/^[a-z]|_[a-z]/) { |str| str[-1].upcase }
  end.join("::")
end

def reindent_module(path)
  contents = File.read(path)
  preamble = contents[/\A(.*)^(?:module|class)/m, 1]
  contents.sub!(preamble, "") if preamble

  namespace_mod = contents[/(?:module|class) (\S+)/, 1]
  return unless namespace_mod.include?("::")

  contents.sub!(namespace_mod, namespace_mod.split("::").last)
  namespace_mod.split("::")[0...-1].reverse_each do |mod|
    contents = "module #{mod}\n#{contents.gsub(/^/, '  ')}end\n"
  end

  contents.gsub!(/^\s+$/, "")
  File.write(path, [preamble, contents].join)
  git "add", path
end

def gh_present?
  system "gh label clone -h > /dev/null 2>&1"
rescue StandardError
  false
end

def create_labels(github_repo)
  system "gh label clone mattbrictson/tomo-plugin --repo #{github_repo.shellescape}"
end

main if $PROGRAM_NAME == __FILE__
