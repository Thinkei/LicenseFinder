# frozen_string_literal: true

module LicenseFinder
  class Yarn < PackageManager
    SHELL_COMMAND = 'yarn licenses list --no-progress --json'

    def possible_package_paths
      [project_path.join('yarn.lock')]
    end

    def current_packages
      cmd = "#{Yarn::SHELL_COMMAND}#{production_flag}"
      suffix = " --cwd #{project_path}" unless project_path.nil?
      cmd += suffix unless suffix.nil?

      stdout, _stderr, status = Cmd.run(cmd)
      return [] unless status.success?

      packages = []
      incompatible_packages = []

      json_strings = stdout.encode('ASCII', invalid: :replace, undef: :replace, replace: '?').split("\n")
      json_objects = json_strings.map { |json_object| JSON.parse(json_object) }

      if json_objects.last['type'] == 'table'
        license_json = json_objects.pop['data']
        packages = packages_from_json(license_json)
      end

      json_objects.each do |json_object|
        match = /(?<name>[\w,\-]+)@(?<version>(\d+\.?)+)/ =~ json_object['data'].to_s
        if match
          package = YarnPackage.new(name, version, spec_licenses: ['unknown'])
          incompatible_packages.push(package)
        end
      end

      packages += incompatible_packages.uniq

      # filter toplevel package
      packages.select! do |package|
        toplevel_packages[package.name] == package.version
      end

      # update children
      Dir.chdir(project_path) do
        packages.each do |package|
          out, _stderr, _status = Cmd.run("yarn info --json #{package.name}@#{package.version} | jq '.data' | jq '.dependencies'")
          next if out.empty?

          children = JSON.parse(out)&.keys
          next if children.nil? || children.empty?

          package.children = children
        end
      end

      packages
    end

    def toplevel_packages
      return @toplevel_packages if defined?(@toplevel_packages)

      package_json_content = JSON.parse(File.read("#{project_path}/package.json"))
      @toplevel_packages = {}

      Dir.chdir(project_path) do
        package_json_content['dependencies'].each_key do |package|
          out, _err, _status = Cmd.run(
            "yarn list -s --depth=0 --pattern '#{package}' | tail -n 1 | sed 's/.*@//g'"
          )

          @toplevel_packages[package] = out.strip
        end
      end

      @toplevel_packages
    rescue StandardError => e
      puts "Get filter dependencies error => #{e.message}"
      raise e
    end

    def prepare
      prep_cmd = "#{prepare_command}#{production_flag}"
      _stdout, stderr, status = Dir.chdir(project_path) { Cmd.run(prep_cmd) }
      return if status.success?

      log_errors stderr
      raise "Prepare command '#{prep_cmd}' failed" unless @prepare_no_fail
    end

    def self.takes_priority_over
      NPM
    end

    def package_management_command
      'yarn'
    end

    def prepare_command
      'yarn install --ignore-engines --ignore-scripts'
    end

    private

    def packages_from_json(json_data)
      body = json_data['body']
      head = json_data['head']

      packages = body.map do |json_package|
        Hash[head.zip(json_package)]
      end

      valid_packages = filter_yarn_internal_package(packages)

      valid_packages.map do |package_hash|
        YarnPackage.new(
          package_hash['Name'],
          package_hash['Version'],
          spec_licenses: [package_hash['License']],
          homepage: package_hash['VendorUrl'],
          authors: package_hash['VendorName'],
          install_path: project_path.join(modules_folder, package_hash['Name'])
        )
      end
    end

    def modules_folder
      return @modules_folder if @modules_folder

      stdout, _stderr, status = Cmd.run('yarn config get modules-folder')
      @modules_folder = 'node_modules' if !status.success? || stdout.strip == 'undefined'
      @modules_folder ||= stdout.strip
    end

    # remove fake package created by yarn [Yarn Bug]
    def filter_yarn_internal_package(all_packages)
      internal_package_pattern = /workspace-aggregator-[a-zA-z0-9]{8}-[a-zA-z0-9]{4}-[a-zA-z0-9]{4}-[a-zA-z0-9]{4}-[a-zA-z0-9]{12}/
      yarn_internal_package = all_packages.find { |package| internal_package_pattern.match(package['Name']) }
      all_packages - [yarn_internal_package]
    end

    def production_flag
      return '' if @ignored_groups.nil?

      @ignored_groups.include?('devDependencies') ? ' --production' : ''
    end
  end
end
