require 'json'
require 'docsplit'
require 'pry'

class GetDocs
  def initialize(data, doc_url_field)
    @data = JSON.parse(data)
    @doc_url_field = doc_url_field
  end

  # Download all documents and text
  def get_all
    get_docs
    get_text
    return JSON.pretty_generate(@data)
  end

  # Generate alt url
  def gen_alt_url(item)
    arr = Array.new
    if item["doc_cloud_id"]
      item["doc_cloud_id"].each do |id|
        arr.push("https://documentcloud.org/documents/"+id+".html")
      end
    end
    return arr
  end

  # Download all documents
  def get_docs
    outarr = Array.new
    @data.each do |item|
      url = item[@doc_url_field]
      url = gen_alt_url(item) if item[@doc_url_field] == nil
      arrhash = item
    
      # If there are documents to download, get each one
      if url
        patharr = Array.new
        url.each do |link|
          patharr.push(download_file(link))
        end
        
        # Add path to doc field
        arrhash["path"] = patharr
      end
      outarr.push(arrhash)
    end
    @data = outarr
  end

  # Fix html link so it links to pdf
  def fix_html_link(link)
    return link.gsub("documentcloud.org", "assets.documentcloud.org").sub("-", "/").gsub(".html", ".pdf").gsub("www.", "")
  end

  # Download individual file if it doesn't exist already
  def download_file(link)
    link = fix_html_link(link)if link.include?(".html")
    path = link.split("/").last

    # Download file
    if !File.exist?("../docs/"+path)
      `wget --no-check-certificate -P ../docs #{link.gsub("https", "http")}`
    end
    return path
  end

  # Get the path to the text given the file path
  def text_path(file_path)
    return file_path.gsub("../docs", "../text").gsub(".pdf", ".txt")
  end

  # OCR the file if it doesn't exist and return the text
  def ocr_file(file_path)
    if !File.exist?(text_path(file_path))
      begin
        Docsplit.extract_text(file_path, :output => '../text')
      rescue
      end
    end

    text = ""
    text = File.read(text_path(file_path)) if File.exist?(text_path(file_path))
    return text
  end

  # Get text for document
  def get_text
    outarr = Array.new
    @data.each do |item|
      paths = item["path"]
      item["text"] = ""
     
      # OCR all files and save
      paths.each { |path| item["text"] += ocr_file("../docs/"+path)} if paths
      outarr.push(item)
    end
    @data = outarr
  end
end
