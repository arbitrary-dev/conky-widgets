#!/usr/bin/python

from lxml import html
import requests
import re

# Here goes all the settings

city_id = '4476'
days_map = {'ПН': 'Mon', 'ВТ': 'Tue', 'СР': 'Wed', 'ЧТ': 'Thu',
  'ПТ': 'Fri', 'СБ': 'Sat', 'ВС': 'Sun'}
day_xpath = '//div[contains(@id, "tab_wdaily")][{}]/dl/dt/text()'
table_xpath = '//tbody[contains(@id, "tbwdaily")][{}]'
daytime_xpath = 'tr[contains(@class, "wrow")][{}]'
temp_xpath = 'td[@class="temp"]/span[1]/text()'
weather_xpath = 'td[@class="clicon"]/img/@src'
image_pat = re.compile('(?:c(\d)){0,1}\.?(?:r(\d)){0,1}\.?(?:s(\d)){0,1}\.?(st){0,1}\.\w+$')

# Start the parsing right away!

page = requests.get('https://gismeteo.ru/city/hourly/' + city_id,
  headers={'user-agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:41.0) Gecko/20100101 Firefox/41.0'})
tree = html.fromstring(page.text)

def check_w( ref, val ):
  return ref if val == None or ref >= int(val) else int(val)

def parse( d ):
  temp = 0
  weather = None
  w_c, w_r, w_s, w_st = 0, 0, 0, False
  table_el = tree.xpath(table_xpath.format(d))[0]
  r = range(3, 8)

  for i in r:
    daytime_el = table_el.xpath(daytime_xpath.format(i))[0]
    temp += int(daytime_el.xpath(temp_xpath)[0].replace('−', '-'))

    weather = re.search(image_pat, daytime_el.xpath(weather_xpath)[0])
    w_c = check_w(w_c, weather.group(1))
    w_r = check_w(w_r, weather.group(2))
    w_s = check_w(w_s, weather.group(3))
    w_st = True if w_st or weather.group(4) else False

  temp = round(temp / len(r))

  return "{0} {1:{2}d} {3}{4}{5}{6}".format(
    days_map[tree.xpath(day_xpath.format(d))[0]],
    temp, '+' if temp else ' ',
    '' if w_r == 0 else 'r' + str(w_r),
    '' if w_r > 0 or w_s == 0 else 's' + str(w_s),
    '' if w_c == 0 else 'c' + str(w_c),
    'st' if w_st else '') \
      .replace('-', '−') # Return justice

print('{};{};{}'.format(
  parse(1),
  parse(2),
  parse(3)))

