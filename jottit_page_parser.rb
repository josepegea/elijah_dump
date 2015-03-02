# Parses a page, using one of its specialized helper classes

require './meeting'
require './node_additions'
require './date_additions'
require './string_additions'

class JottitPageParser
  
  @page_data = nil
  @page_doc = nil
  @page_content = nil
  @meeting = nil
  
  def parse_page(page_data)
    set_page_data(page_data)
    break_page_in_chapters
    parse_chapters
    return @meeting
  end
  
  private
  
  def set_page_data(page_data)
    @page_data = page_data
    @page_doc = Nokogiri::HTML(@page_data)
    @page_content = @page_doc.at_css('#content')
    @meeting = Meeting.new()
    @nodes_for_metadata = []
    @index_h1 = nil
    @index_offered_by = nil
    @index_attendees = nil
    @index_speaker = nil
    @found_links = []
  end
  
  def break_page_in_chapters
    @page_chapters = @page_content.break_in_header_chapters
  end
  
  # Applies different heuristics and fires the correct parser for the page
  def parse_chapters
    find_indexes
    return if @index_h1.nil?
    get_main_content
    get_content_for_metadata
    process_metadata
    process_found_links
    find_missing_links
  end
  
  def get_main_content
    header = @page_chapters[@index_h1][:header]
    contents = @page_chapters[@index_h1][:contents]
    @meeting.title = header.content
    @found_links.concat(header.css('a').to_a)
    details = ""
    contents.each do |node|
      if @index_h1 == 0 && node_has_metadata?(node)
        # These are not really details
        @nodes_for_metadata << node
      else
        details << node.to_html
      end
    end
    @meeting.details = details
  end
  
  # If there are no @nodes_for_metadata and index_h1 > 0, tries to find content for metadata
  # from the prefix
  
  def get_content_for_metadata
    if @nodes_for_metadata.nil? || @nodes_for_metadata.empty?
      if @index_h1 > 0
        @page_chapters[0..(@index_h1 - 1)].each do |chapter|
          chapter[:contents].each do |node|
            if node_has_metadata?(node)
              @nodes_for_metadata << node
            end
          end
        end 
      else
        puts "No contents for metadata in page: #{@page_chapters.to_yaml}"
      end
    end
  end
  
  def process_metadata
    metadata_text = (@nodes_for_metadata.map {|n| n.text }).join("\n")
    parse_date(metadata_text)
    parse_time(metadata_text)
    parse_venue(metadata_text)
    @nodes_for_metadata.each do |node|
      @found_links.concat(node.css('a').to_a)
    end
  end
  
  def process_found_links
    # raise @found_links.inspect
    puts "Found links #{@found_links.size} - #{@found_links.inspect}"
    @found_links.each do |node|
      # Video ...
      if @meeting.video_url.nil? && node[:href] =~ /vimeo\.com/
        @meeting.video_url = node[:href]
      end
      # Map ...
      if @meeting.map_url.nil? && node[:href] =~ /g(oogle)?\.(com|es|co)\/maps/
        @meeting.map_url = node[:href]
      end
    end
  end
  
  # Sometimes, videos are in strange places...
  
  def find_missing_links
    # TODO
  end
  
  def parse_date(text)
    date = Date.parse_madrid_rb_date(text)
    if date
      @meeting.meeting_date = date
    end
  end

  def parse_time(text)
    time = text.parse_madrid_rb_time
    if time
      @meeting.meeting_time = time
    end
  end

  def parse_venue(text)
    venue = text.parse_madrid_rb_venue
    if venue
      @meeting.venue = venue
    end
  end
  
  # Tries to determine the indexes of the relevant chapters
  
  def find_indexes
    @page_chapters.each_index do |idx|
      h = @page_chapters[idx][:header]
      if h
        hcontent = h.content
        @index_h1 = idx if h.name == 'h1'
        @index_offered_by = idx if hcontent == 'Ofrecido por' || hcontent == 'Offered by'
        @index_attendees = idx if hcontent == 'Asistentes' || hcontent == 'Attendees'
        @index_speaker = idx if   @index_speaker.nil? &&
                                  @index_h1 && 
                                  idx != @index_offered_by &&
                                  idx != @index_speaker
      end
    end
    puts "No h1 in page: #{@page_chapters.to_yaml}" if @index_h1.nil?
    # puts "Index of h1: #{@index_h1}"
  end
  
  # Returns true if the text inside the node contains relevant field content
  
  def node_has_metadata?(node)
    raw_text = node.content.downcase
    # puts "Find metadata in: #{raw_text}"
    return true if raw_text =~ /fecha\:\s/
    return true if raw_text =~ /hora\:\s/
    return true if raw_text =~ /lugar\:\s/
    return true if raw_text =~ /date\:\s/
    return true if raw_text =~ /time\:\s/
    return true if raw_text =~ /venue\:\s/
    # No relevant field found, so this is not a metadata block
    return false
  end
  
end