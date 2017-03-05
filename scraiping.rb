#
# encoding:utf-8

#
require './lib/holidaydoc_ishikawa.rb'

# URL
url = 'http://i-search.pref.ishikawa.jp/toban/index.php?a=3'

# Scraping & Output json data
holiday_doc = HolidayDoc.new
#
holiday_doc.read_data(url)
holiday_doc.write_json()
