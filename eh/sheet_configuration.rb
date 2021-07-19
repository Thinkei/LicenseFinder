module SheetConfiguration
  module_function

  def format_header_row(sheet_id)
    {
      repeat_cell: {
        range: {
          sheet_id: sheet_id,
          start_row_index: 0,
          end_row_index: 1
        },
        cell: {
          user_entered_format: {
            background_color: {
              red: 128,
              green: 128,
              blue: 128
            },
            horizontal_alignment: 'LEFT',
            text_format: {
              foreground_color: {
                red: 1.0,
                green: 1.0,
                blue: 1.0
              },
              font_size: 12,
              bold: true
            }
          }
        },
        fields: 'user_entered_format(background_color,text_format,horizontal_alignment)'
      }
    }
  end

  def frozen_first_row(sheet_id)
    {
      update_sheet_properties: {
        properties: {
          sheet_id: sheet_id,
          grid_properties: {
            frozen_row_count: 1
          }
        },
        fields: 'grid_properties.frozen_row_count'
      }
    }
  end

  def conditional_formatting(sheet_id)
    {
      add_conditional_format_rule: {
        rule: {
          ranges: [
            {
              sheet_id: sheet_id,
              start_column_index: 0,
              end_column_index: 10,
              start_row_index: 0,
              end_row_index: 1000
            }
          ],
          boolean_rule: {
            condition: {
              type: 'CUSTOM_FORMULA',
              values: [
                {
                  user_entered_value: '=$C1="unknown"'
                }
              ]
            },
            format: {
              background_color: {
                green: 0.2,
                red: 0.8
              }
            }
          }
        },
        index: 0
      }
    }
  end

  def dimension_properties(sheet_id)
    {
      update_dimension_properties: {
        range: {
          sheet_id: sheet_id,
          dimension: 'COLUMNS',
          start_index: 0,
          end_index: 10
        },
        properties: {
          pixel_size: 200
        },
        fields: 'pixelSize'
      }
    }
  end
end

