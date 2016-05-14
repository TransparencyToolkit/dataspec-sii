require 'json'
load 'processbibtex.rb'
load 'getdocs.rb'

url_prefix = "localhost:3000/docs/"

# Process bibtex data
p = ProcessBibtex.new("../raw_data/SII.bib", url_prefix)
companies, materials = p.process

# Get text
g = GetDocs.new(materials, "bdsk_url_1")
materials_with_text = g.get_all

# Write to files
File.write('../material_data/materials.json', materials_with_text)
File.write('../company_data/companies.json', companies)
