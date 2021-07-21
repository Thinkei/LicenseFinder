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
  def to_s
    licence_records = [@columns]
    sorted_dependencies.each do |s|
      licence_records << format_dependency(s)
    end
    licence_records
  end
end
