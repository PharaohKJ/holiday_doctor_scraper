# coding: utf-8

require 'open-uri'
require 'nokogiri'
require 'json'

# ----------------------------------------------------------------------
#  HolidayDoc
# ----------------------------------------------------------------------
class HolidayDoc
  @@count  = 1
  #
  @@header   = { "name" => "holiday_doctor",    # json_name
                 "count" => 1,                  # 
                 "frequency" => "Daily",        # Daily or Weekly or Monthly
                 "version" => 1,                # 
                 "newdata" => true,             # true or false
                 "lastrunstatus" => nil,        # success or fail
                 "thisversionstatus" => nil,    # success or fail
                 "nextrun" => nil,              # Date
                 "thisversionrun" => nil,       # Date
                 "results" => Hash::new }       # -> @@body
  @@body     = { "collection1" => Hash::new,    # -> contents of holiday_doctor
                 "collection2" => Hash::new }   # -> @@footer
  @@footer   = { "date" => nil,                 # Date from content
                 "index" => 1,                  # 
                 "url" => nil }                 # url from reference url
  #
  @@itembox_array = Array::new
  @@footer_array = Array::new
  #
  @@item_date = ""
  @@holiday_date_str = ""
  #
  @@output_json = nil
  #
  @@b_threshold_day = 14
  @@f_threshold_day = 7
  #
  def initilize()
    @@count = 1
    @@holiday_date_str = ""
  end
  #
  def parse_data(url)
  #
    hash_tbl = { "医療機関名".to_sym => :name,  # 
                 "住所".to_sym => :address,     # 
                 "電話番号".to_sym => :tel,     # 
                 "科目名".to_sym => :category , # 
                 "診療時間".to_sym => :time  }  # 
    #
    charset = nil
    #
    begin
      html = open(url) do |f|
        charset = f.charset
        f.read
      end
    rescue
      # Error処理
      return false
    end

    index_name = Array::new
    content_data = Array::new
    itembox = Array::new
    
    # temporal setting
    charset = 'UTF-8'

    # parse
    doc = Nokogiri::HTML.parse(html, nil, charset)

    # Analyze Date
    main_object  = doc.xpath('//div[@id="maincolumn"]')
    item_objects = doc.xpath('//div[@id="sub_date"]|//div[@id="item-box"]')

    # Create table data from html@id=item-box
    item_objects.each {|object|
      if (object.attribute("id").text == 'sub_date') then
        @@itemdate = object.children.text
      end
      object.search('th').each {|item| index_name.push(item.text.gsub(/[  ]/,''))}
      object.search('td').each {|item| content_data.push(item.text.gsub(/[\n\t  ]/,'').gsub(" ",""))}
      itemhash = Hash[index_name.map{|v| hash_tbl[v.to_sym]}.zip(content_data)]

      # Add date into :date key
      unless itemhash.empty?
        itemhash.store(:date,@@itemdate)
        itembox << itemhash
      end
    }

    # Create required data
    itembox.sort_by!{|h| h[:category]}.each {|array|
      array["index"] = @@count
      array["url"]   = url
      @@count = @@count + 1
    }
    #
    itembox.each {|v|
      if /(\d+)(月)(\d+)(日)/ =~ v[:date] then
        month = $1
        mday  = $3
        tdate = Date.today
        ddate = Date.new(tdate.year, month.to_i, mday.to_i)
        if ((ddate.yday + @@f_threshold_day) > tdate.yday) & ((ddate.yday - @@b_threshold_day) < tdate.yday) then
          # Remove :date key
          @@holiday_date_str = v[:date]
          v.delete(:date)
          # Add itembox to itembox_array
          @@itembox_array << v
        end
      end
    }

    # Check next data
    next_url = nil
    if main_object.search('a').any? {|v| next_url = v.attribute("href"); v.text.include?("次へ") } then
      ret_code = parse_data(next_url)
    end
    #
    return true
  end
  #
  def read_data(url)
    index_name   = Array::new
    content_data = Array::new
    # 
    current_time = DateTime.now
    next_time = current_time + 1
    # 
    ret_code = parse_data(url)
    if (ret_code == true) then
      status_msg   = "success"
    else
      status_msg   = "fail"
    end
    #
    @@header["thisversionrun"]    = current_time.rfc822
    @@header["thisversionstatus"] = status_msg
    @@header["nextrun"]           = next_time.rfc822
    #
    @@footer["date"]              = @@holiday_date_str
    @@footer["url"]               = url
    #
    @@footer_array << @@footer
    #
    @@body["collection1"]         = @@itembox_array
    @@body["collection2"]         = @@footer_array
    #
    @@header["results"]           = @@body
  end
  def write_json()
    #
    @@output_json = JSON.generate(@@header)
    #
    puts @@output_json
  end
end
