require 'json'
require 'bibtex'
require 'pry'

class ProcessBibtex
  def initialize(file, url_prefix)
    @file = file
    @string_fields = ["company-name", "email", "website", "ceo", "telephone", "twitter-handle", "founder", "csr", "incorporation-date", "name", "year-collected"]
    @name_remap = {"catergory" => "category", "screenshot_of_product" => "image_of_product", "company" => "company_name", "iss_world" => "trade_show", "trade_show_collected" => "trade_show"}
    @ignore_fields = ["image_of_product", "annote", "year_collected"]
    @merge_fields = [["technology_sold", "technology_sold_web_version"], ["type_of_media", "document_title"]]
    @url_prefix = url_prefix
  end
 
  # Fix links to work with rails
  def fix_link(link_text)
    if link_text.include?("www.") && !link_text.include?("http")
      return link_text.gsub("www.", "http://")
    else
      return link_text
    end
  end

  # Chagne spy files 1 to 2 and 2 to 3
  def switch_volume_num(val)
    return "2" if val.to_s == "1"
    return "3" if val.to_s == "2"
  end

  # Keep only allowed values
  def clean_val_disallowed(field, val)
    if process_bibtex_key(field) == "spy_files_release_volume"
      clean_val = val.reject{|v| (v != "1" && v != "2" && v != "3")}
      val = switch_volume_num(clean_val)
    elsif process_bibtex_key(field) == "bibtex_type"
      if val == "company"
        return "Company"
      elsif val == "materials"
        return "Document"
      end
    end

    return val
  end

  # Turn value into proper strings or arrays
  def process_bibtex_val(key, value)
    # Company name and some other fields should be string
    if @string_fields.include?(key)
      return fix_link(remove_brackets(value.to_s).strip.lstrip)

    # Return arrays for list values
    elsif value.to_s.include?("{") || value.to_s.include?("}")
      arr = remove_brackets(value).split(",")
      return arr.map{|a| fix_link(a.strip.lstrip)}

    else # Make vlaue a string
      return fix_link(value.to_s.strip.lstrip)
    end
  end

  # Remove brackets from the value
  def remove_brackets(val)
    return val.gsub("{", "").gsub("}", "")
  end

  # Concatenate the fields entered
  def concatenate_fields(fields)
    outstr = ""
    fields.each do |k, v|
      outstr += remove_brackets(v.to_s)+"<br />"
    end

    return outstr if !outstr.empty?
  end

  # Combined the fields that include a certain string
  def gen_combined_fields(item, get_includes)
    fields = item.select {|k, v| k.to_s.include?(get_includes)}
    concatenate_fields(fields)
  end

  # List of relevant blog entries
  def gen_blog_list(item)
    fields = item.select {|k, v| k.to_s.include?("blog")}
    return fields.map{|k, v| "https://privacyinternational.org/"+remove_brackets(v)}
  end

  # Process bibtex key to be a string, rails safe, and remap as needed
  def process_bibtex_key(key)
    key = key.to_s.gsub("-", "_")
    key = @name_remap[key] if @name_remap[key]
    return key
  end

  # Add the document cloud link field if it doesn't exist
  def add_doc_cloud_link(item)
    if item["doc_cloud_link"] == nil && item["doc_cloud_id"]
      arr = Array.new
      item["doc_cloud_id"].each do |id|
        arr.push("https://documentcloud.org/documents/"+id+".html")
      end
      item["doc_cloud_link"] = arr
    end
    
    return item
  end

  # Merge all fields
  def merge_fields(h)
    @merge_fields.each do |field_combo|
      first_field = process_bibtex_key(field_combo[0])
      merge_with_field = process_bibtex_key(field_combo[1])

      # Both fields exist
      if h[first_field] && h[merge_with_field]
        h[first_field] = h[first_field].concat(h[merge_with_field]).uniq

      # First field does not exist  
      elsif h[merge_with_field] && !h[first_field]
        h[first_field] = h[merge_with_field]
      end # In other cases, nothing needs to be done
      h.delete(merge_with_field)
    end

    return h
  end

  # Set name to doc_title when media type is presentation. Otherwise, merge document title with type of document
  def fix_title_type_fields(processed_hash)
    # If media type is presentation, set name to doc title
    if processed_hash["type_of_media"]
      # Move document title to document name for presentations
      if processed_hash["type_of_media"].include?("Presentation") || processed_hash["type_of_media"].include?("Company Information")
        processed_hash["name"] = processed_hash["document_title"][0] if processed_hash["document_title"] && !processed_hash["document_title"].empty?
        processed_hash.delete("document_title") # Remove field
        return merge_fields(processed_hash)
        
      # Generate name for company report field
      elsif processed_hash["type_of_media"].include?("Company Report")
        return gen_company_report_name(processed_hash)
      end
    end
    # Otherwise, just merge the fields
    return merge_fields(processed_hash)
  end

  # Generate company report name
  def gen_company_report_name(hash)
    name = fix_company_name(hash)["company_name"] + " Report"
    hash["name"] = name
    return hash
  end

  # Turns an array into a natural sentence
  def array_to_sentence(arr)
    if arr.length == 1
      return arr[0]
    elsif arr.length == 2
      return arr[0] + " and " + arr[1]
    elsif arr.length > 2
      arr[arr.length-1] = "and "+arr[arr.length-1]
      return arr.join(", ")
    elsif arr.length == 0
      return "?"
    end
  end

  # Generates a company description
  def gen_company_description(item)
    description = ""
    description += item["company_name"] + " makes " +array_to_sentence(item["technology_sold"]) + " technology. " if item["company_name"] && item["technology_sold"]
    description += "Their headquarters is in " + item["hq_city"][0]+". " if item["hq_city"]
    description += "They have offices in "+ array_to_sentence(item["offices_in"])+"." if item["offices_in"]
    item[:description] = description
  
    return item
  end
  
  # Process the individual bibtex item
  def process_bibtex_item(item)
    item_hash = item.to_hash
    processed_hash = Hash.new
    
    # Go through each item and save keys and processed values
    item_hash.each do |key, value|
      if !@ignore_fields.include?(process_bibtex_key(key)) # Check if it should be removed/ignored
        processed_value = clean_val_disallowed(key, process_bibtex_val(key.to_s, value))
        processed_hash[process_bibtex_key(key)] = processed_value
      end
    end

    # Get address and news fields
    address = gen_combined_fields(item_hash, "address-line")
    news = gen_combined_fields(item_hash, "news")
    blogs = gen_blog_list(item_hash)
    processed_hash["address"] = address if address
    processed_hash["news"] = news if news

    # Fix the document title and type fields
    # Also includes merge
    processed_hash = fix_title_type_fields(processed_hash)
    processed_hash = fix_company_name(processed_hash)
    processed_hash = add_doc_cloud_link(processed_hash)
    
    # Add company description and list of docs
    if processed_hash["bibtex_type"].downcase == "company"
      processed_hash = gen_company_description(processed_hash)
      processed_hash = add_list_of_docs_for_company(processed_hash)
    end
    
    return processed_hash unless dont_return?(processed_hash)
  end

  # Get a list of documents for 
  def add_list_of_docs_for_company(phash)
    docs = JSON.parse(File.read("../material_data/materials.json"))
    matches = docs.select{|i| i["company_name"].downcase.include?(phash["company_name"].downcase)}

    # Make a list of matches
    match_list = Array.new
    matches.each do |m|
      match_list.push([m["name"], m["bibtex_key"]+"sii_documents"])
    end
    
    phash["company_documents"] = match_list
    return phash
  end

  # Remove underscores
  def fix_company_name(processed_hash)
    if processed_hash["company_name"].is_a?(Array)
      processed_hash["company_name"] = processed_hash["company_name"].first.gsub("_", " ")
    else
      processed_hash["company_name"] = processed_hash["company_name"].gsub("_", " ")
    end

    return processed_hash
  end

  # Checks if item is released to determine if it should be returned
  def dont_return?(processed_hash)
    # Remove if it hasn't been released
    if processed_hash["released"]
      return true if processed_hash["released"][0] == "NO"
    end

    # Remove if it has video in type
    if processed_hash["type_of_media"]
      return true if processed_hash["type_of_media"].include?("Video")
    end
  end

  # Turn bibtex file into JSON with companies separated out
  def process
    # Load in companies and materials
    bibtex = BibTeX.open(@file)
    companies_bib = bibtex['@company']
    materials_bib = bibtex['@materials']
    
    # Turn into JSON via hash
    companies = companies_bib.map{|company| process_bibtex_item(company)}.compact
    materials = materials_bib.map{|material| process_bibtex_item(material)}.compact

    # Write to companies and materials JSONs
    return JSON.pretty_generate(companies), JSON.pretty_generate(materials)
  end
end
