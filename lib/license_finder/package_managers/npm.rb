# frozen_string_literal: true

require 'json'
require 'tempfile'

module LicenseFinder
  class NPM < PackageManager
    def initialize(options = {})
      super
      @npm_options = options[:npm_options]
    end

    def current_packages
      packages = NpmPackage.packages_from_json(npm_json, detected_package_path)

      # filter toplevel package
      packages.reject! do |p|
        !toplevel_packages.keys.include?(p.name) ||
          (toplevel_packages.keys.include?(p.name) && toplevel_packages[p.name] != p.version)
      end

      # reupdate dependencies
      Dir.chdir(project_path) do
        packages.each do |p|
          out, _err, _status = Open3.capture3("npm view --json #{p.name}@#{p.version} dependencies")
          package.children = JSON.parse(out).keys
        end
      end
      packages
    end

    def package_management_command
      'npm'
    end

    def prepare_command
      'npm install --no-save --ignore-scripts'
    end

    def possible_package_paths
      [project_path.join('package.json')]
    end

    def prepare
      prep_cmd = "#{prepare_command}#{production_flag}"
      _stdout, stderr, status = Dir.chdir(project_path) { Cmd.run(prep_cmd) }

      return if status.success?

      log_errors stderr
      raise "Prepare command '#{prep_cmd}' failed" unless @prepare_no_fail
    end

    private

    def toplevel_packages
      return @toplevel_packages if defined?(@toplevel_packages)
      package = JSON.parse(File.read("#{project_path}/package.json"))
      @toplevel_packages = {}

      Dir.chdir(project_path) do
        package['dependencies'].keys.each do |package|
          out, _err, _status = Open3.capture3("npm view '#{package}' version")

          @toplevel_packages[package] = out.strip
        end
      end

      @toplevel_packages
    rescue StandardError => e
      puts "Get filter dependencies error => #{e.message}"
      {}
    end

    def npm_json
      command = "#{package_management_command} list --json --long#{production_flag}"
      command += " #{@npm_options}" unless @npm_options.nil?
      stdout, stderr, status = Dir.chdir(project_path) { Cmd.run(command) }
      # we can try and continue if we got an exit status 1 - unmet peer dependency
      raise "Command '#{command}' failed to execute: #{stderr}" if !status.success? && status.exitstatus != 1

      JSON.parse(stdout)
    end

    def production_flag
      return '' if @ignored_groups.nil?

      @ignored_groups.include?('devDependencies') ? ' --production' : ''
    end
  end
end
