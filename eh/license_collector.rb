# frozen_string_literal: true

require 'license_finder'

#project_path = "/home/thinkstation/workspace/marketplace-service"
#generate_licenses_command = "docker run --rm -v #{project_path}:/scan -w /scan license-report license_finder report --prepare  --format csv --save /scan/licenses-report.csv"

module LicenseCollector
  module_function

  def configuration(project_path)
    LicenseFinder::Configuration.with_optional_saved_config(
      logger: :quite,
      project_path: project_path
    )
  end

  def call(project_path)
    puts "Reporting the license of #{project_path}"

    lf = LicenseFinder::Core.new(configuration(project_path))
    lf.decisions.ignore_group(:test)
    lf.decisions.ignore_group(:development)
    lf.decisions.ignore_group(:devDependencies)

    lf.prepare_projects
    lf
  rescue StandardError => e
    puts "Reporting license was failed - #{e.message}"
  end
end

class WorksheetReport < LicenseFinder::CsvReport
  def to_s(include_dependencies: false)
    if include_dependencies
      licence_records = [@columns << 'dependencies']
    else
      licence_records = [@columns]
    end

    sorted_dependencies.each do |s|
      licence_records << reformat_dependency(s, include_dependencies: include_dependencies)
    end
    licence_records
  end

  def reformat_dependency(dependency, include_dependencies: false)
    data = format_dependency(dependency)

    if include_dependencies
      data << dependency.children&.map(&:name)&.join(', ')
    end
    data
  end
end
