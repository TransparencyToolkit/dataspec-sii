require 'json'
require 'pry'

class FindBroken
  def initialize(file, check_field, id_field)
    @file = JSON.parse(File.read(file))
    @check_field = check_field
    
    @id_field = id_field
    @broken_ids = Array.new
  end

  # Find all documents missing or with an empty field
  def find_empty
    @file.each do |item|
      # Find items without field
      if !item[@check_field]
        @broken_ids.push(item[@id_field])

      # Find empty items
      elsif item[@check_field].empty?
        @broken_ids.push(item[@id_field])
      end
    end

    return JSON.pretty_generate(@broken_ids)
  end
end

f = FindBroken.new("../material_data/materials.json", "name", "bibtex_key")
puts f.find_empty
