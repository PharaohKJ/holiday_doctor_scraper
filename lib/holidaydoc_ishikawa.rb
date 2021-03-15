# frozen_string_literal: true

require 'open-uri'
require 'nokogiri'
require 'json'
require 'holiday_jp'

# ----------------------------------------------------------------------
#  HolidayDoc
# ----------------------------------------------------------------------
class HolidayDoc
  @@count = 1
  #
  @@header   = { 'name'              => 'holiday_doctor', # json_name
                 'count'             => 1, #
                 'frequency'         => 'Daily', # Daily or Weekly or Monthly
                 'version'           => 1,                #
                 'newdata'           => true,             # true or false
                 'lastrunstatus'     => nil, # success or fail
                 'thisversionstatus' => nil, # success or fail
                 'nextrun'           => nil, # Date
                 'thisversionrun'    => nil, # Date
                 'results'           => {} } # -> @@body
  @@body     = { 'collection1' => {},    # -> contents of holiday_doctor
                 'collection2' => {} }   # -> @@footer
  @@footer   = { 'date'  => nil, # Date from content
                 'index' => 1, #
                 'url'   => nil } # url from reference url
  #
  @@itembox_array = []
  @@footer_array = []
  @@item_date = ''
  @@holiday_date_str = ''
  @@base_url = nil
  @@output_json = nil
  def initilize
    @@count = 1
    @@holiday_date_str = ''
  end

  def parse_data(url)
    hash_tbl = {
      '医療機関名': :name,
      '住所':    :address,
      '電話番号':  :tel,
      '科目名':   :category,
      '診療時間':  :time
    }
    charset = nil
    begin
      @@base_url = get_uri_wo_filename(url)
      html = URI.open(url) do |f|
        charset = f.charset
        f.read
      end
    rescue StandardError
      # Error処理
      return false
    end

    index_name = []
    content_data = []
    itembox = []

    # temporal setting
    charset = 'UTF-8'

    # parse
    doc = Nokogiri::HTML.parse(html, nil, charset)

    # Analyze Date
    main_object  = doc.xpath('//div[@id="maincolumn"]')
    item_objects = doc.xpath('//div[@id="sub_date"]|//div[@id="item-box"]')

    # Create table data from html@id=item-box
    item_objects.each do |object|
      @@itemdate = object.children.text if object.attribute('id').text == 'sub_date'
      object.search('th').each { |item| index_name.push(item.text.gsub(/[  ]/, '')) }
      object.search('td').each { |item| content_data.push(item.text.gsub(/[\n\t  ]/, '').gsub(' ', '')) }
      itemhash = Hash[index_name.map { |v| hash_tbl[v.to_sym] }.zip(content_data)]

      # Add date into :date key
      unless itemhash.empty?
        itemhash.store(:date, @@itemdate)
        itembox << itemhash
      end
    end

    # Create required data
    itembox.sort_by! { |h| h[:category] }.each do |array|
      array['index'] = @@count
      array['url']   = url
      @@count += 1
    end
    itembox.each do |v|
      next unless /(\d+)(月)(\d+)(日)/ =~ v[:date]
      month = Regexp.last_match(1)
      mday  = Regexp.last_match(3)
      tday = Date.today
      dday = Date.new(tday.year, month.to_i, mday.to_i)
      dday = Date.new(tday.year + 1, month.to_i, mday.to_i) if dday < tday
      nday = if (tday.wday >= 1) && (tday.wday <= 6)
               # workday
               if HolidayJp.between(tday, tday + 6 - tday.wday).empty?
                 # next Sun
                 tday + 7 - tday.wday
               else
                 # 1st Data
                 HolidayJp.between(tday, tday + 6 - tday.wday)[0].instance_variable_get('@date')
               end
             else
               # weekday
               tday
             end
      next unless dday == nday
      # Remove :date key
      @@holiday_date_str = v[:date]
      v.delete(:date)
      # Add itembox to itembox_array
      @@itembox_array << v
    end

    # Check next data
    next_url = nil
    if main_object.search('a').any? { |v| next_url = v.attribute('href'); v.text.include?('次へ') }
      next_full_url = @@base_url + get_filename(next_url)
      ret_code = parse_data(next_full_url)
    end
    true
  end

  def get_filename(url)
    url =~ %r{([^/]+?)([?#].*)?$}
    if $&.nil?
      url
    else
      $&
    end
  end

  def get_uri_wo_filename(url)
    url.gsub(get_filename(url), '')
  end

  def read_data(url)
    index_name   = []
    content_data = []
    current_time = DateTime.now
    next_time = current_time + 1
    ret_code = parse_data(url)
    if ret_code == true
      status_msg = 'success'
      # sort by category
      @@itembox_array.sort! { |a, b| a[:category] <=> b[:category] }
    else
      status_msg = 'fail'
    end
    status_msg = 'fail' if @@itembox_array.empty?

    @@header['thisversionrun']    = current_time.rfc822
    @@header['thisversionstatus'] = status_msg
    @@header['nextrun']           = next_time.rfc822
    @@footer['date']              = @@holiday_date_str
    @@footer['url']               = url
    @@footer_array << @@footer
    @@body['collection1']         = @@itembox_array
    @@body['collection2']         = @@footer_array
    @@header['results']           = @@body
  end

  def write_json
    @@output_json = JSON.generate(@@header)
    puts @@output_json
  end
end
