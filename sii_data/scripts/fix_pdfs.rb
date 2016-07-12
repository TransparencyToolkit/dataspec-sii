require 'pry'

class Fixpdfs
  def initialize(path, output_dir)
    @path = path
    @output_dir = output_dir
  end

  # Fix the pdfs
  def fix_pdfs
    Dir.foreach(@path) do |file|
      next if file == '.' or file == '..'
      system("convert #{@path+file} #{@output_dir+file}")
    end
  end
end

f = Fixpdfs.new("/home/shidash/PI/dataspec-sii/sii_data/docs/", "/home/shidash/PI/dataspec-sii/sii_data/fixed_docs/")
f.fix_pdfs
