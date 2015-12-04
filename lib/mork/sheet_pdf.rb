require 'mork/grid_pdf'
require 'prawn'

module Mork

  #TODO: read the prawn manual, we should probably use views

  class SheetPDF < Prawn::Document
    def initialize(content, grip=GridPDF.new)
      @grip = case grip
              when String, Hash; GridPDF.new grip
              when Mork::GridPDF; grip
              else raise 'Invalid initialization parameter'
              end
      super my_page_params
      # @content should be an array of hashes, one per page;
      # convert to array if a single hash was passed
      @content = content.class == Hash ? [content] : content
      process
    end

    def save(fn)
      render_file fn
    end

    def to_pdf
      render
    end

    private

    def my_page_params
      {
        page_size: @grip.page_size,
        margin:    @grip.margins
      }
    end

    def process
      # for all sheets
      line_width 0.3
      font_size @grip.item_font_size
      create_stamps
      make_repeaters
      # for each response sheet
      @content.each_with_index do |content, i|
        start_new_page if i>0
        barcode content[:barcode]
        header content[:header]
        questions_and_choices ch_arr[i]
      end
    end

    def make_repeaters
      repeat(:all) do
        calibration_cells
        fill do
          @grip.reg_marks.each do |r|
            circle r[:p], r[:r]
          end
        end
      end
    end

    def calibration_cells
      @grip.calibration_cells_xy.each { |c| stamp_at 'X', c }
    end

    def barcode(code)
      # draw the dark calibration bar
      stamp_at 'barcode', @grip.ink_black_xy
      # draw the bars corresponding to the code
      # least to most significant bit, left to right
      @grip.barcode_xy_for(code).each { |c| stamp_at 'barcode', c }
    end

    def header(content)
      content.each do |k,v|
        font_size @grip.header_size(k) do
          if @grip.header_boxed?(k)
            bounding_box @grip.header_xy(k), width: @grip.header_width(k), height: @grip.header_height(k) do
              stroke_bounds
              bounding_box @grip.header_padding(k), width: @grip.header_width(k) do
                text v
              end
            end
          else
            text_box v, at: @grip.header_xy(k), width: @grip.header_width(k)
          end
        end
      end
    end

    def questions_and_choices(n_ch)
      n_ch.each_with_index do |n, i|
        text_box "#{i+1}",
                 at: @grip.qnum_xy(i),
                 width: @grip.qnum_width,
                 height: @grip.height_of_cell,
                 align: :right,
                 valign: :center
        stamp_at "s#{n}", @grip.item_xy(i)
      end
    end

    def create_stamps
      create_choice_stamps
      create_stamp('X') do
        cell_stamp_content 'X', 0
      end
      create_stamp('barcode') do
        fill do
          rectangle [0,0], @grip.barcode_width, @grip.barcode_height
        end
      end
    end

    def create_choice_stamps
      ch_arr.flatten.uniq.each do |t|
        create_stamp("s#{t}") do
          t.split("-").each_with_index do |c, i|
            cell_stamp_content c, @grip.choice_spacing*i
          end
        end
      end
    end

    def cell_stamp_content(l, x)
      stroke_rounded_rectangle [x,0],
                               @grip.width_of_cell,
                               @grip.height_of_cell,
                               @grip.cround
      text_box l,
               at:     [x,0],
               width:  @grip.width_of_cell,
               height: @grip.height_of_cell,
               align:  :center,
               valign: :center
    end

    def ch_arr
      @all_choices ||= @content.collect { |c| c[:choices].map { |d| d.join "-" } }
    end
  end
end
