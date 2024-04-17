# frozen_string_literal: true

require 'google_drive'
require 'tempfile'
require_relative 'sheet_configuration'

module GoogleSpreadsheetReport
  module_function

  def session
    return @session if defined?(@session)

    file = Tempfile.new
    file.write(ENV['LICENSE_REPORT_GOOGLE_AUTH_SECRET'])
    file.rewind

    @session ||= GoogleDrive::Session.from_config(file.path)
  end

  def spreadsheet
    @spreadsheet ||= session.spreadsheet_by_key(ENV['LICENSE_REPORT_SPREADSHEET_ID'])
  end

  def worksheet_by_service(service_name)
    worksheets = spreadsheet.worksheets

    worksheet = worksheets.find { |sheet| sheet.title == service_name }

    unless worksheet
      worksheet = spreadsheet.add_worksheet(service_name, 1000, 7)

      worksheet.add_request(SheetConfiguration.dimension_properties(worksheet.sheet_id))
      worksheet.add_request(SheetConfiguration.conditional_formatting(worksheet.sheet_id))
      worksheet.add_request(SheetConfiguration.format_header_row(worksheet.sheet_id))
      worksheet.add_request(SheetConfiguration.frozen_first_row(worksheet.sheet_id))
      worksheet.synchronize
    end

    worksheet
  end

  def call(repo_name, license_records)
    # clear all data
    worksheet = worksheet_by_service(repo_name)
    worksheet.add_request(update_cells: { range: { sheet_id: worksheet.sheet_id }, fields: '*' })
    worksheet.synchronize

    # update new data
    worksheet.insert_rows(worksheet.num_rows + 1, license_records)
    worksheet.add_request(SheetConfiguration.format_header_row(worksheet.sheet_id))
    worksheet.synchronize
  end
end
