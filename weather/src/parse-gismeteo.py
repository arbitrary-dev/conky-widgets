#!/usr/bin/python

from lxml import html
import requests

# settings

city = '4476'
link = 'https://www.gismeteo.ru/weather-perm-%s/3-days'
ua = 'Mozilla/5.0 (X11; Linux x86_64; rv:41.0) Gecko/20100101 Firefox/41.0'

# forecast container

fcc_xpath = '//div[contains(@class, "forecast_container")]'

def get_fcc(tree, city):
    return tree.xpath(fcc_xpath)[0]

# day

day_xpath = 'div/div[contains(@class, "header_item")][%d]/a/text()'

def xday( fcc, day ):
    return fcc.xpath(day_xpath % day)[0]

d_map = {
    'пн': 'Mon',
    'вт': 'Tue',
    'ср': 'Wed',
    'чт': 'Thu',
    'пт': 'Fri',
    'сб': 'Sat',
    'вс': 'Sun'
}

def parse_day( day ):
    return d_map[day[:2].lower()]

def _day( fcc, day ):
    return parse_day(xday(fcc, day))

# temperature

time_calc = '(%d-1)*4+%d'
temp_xpath = 'div[contains(@class, "templine")]/div/div[contains(@class, "item")][' + time_calc + ']/@data-air'

def xtemp( fcc, day, time ):
    return fcc.xpath(temp_xpath % (day, time))[0]

def parse_temp( t ):
    return int(t)

def avg_temp( ts ):
    return round(sum(ts) / len(ts))

def _temp(fcc, day, time_rng):
    ts = [parse_temp(xtemp(fcc, day, t)) for t in time_rng]
    return avg_temp(ts)

# weather

weather_xpath = 'div[contains(@class, "iconline")]/div[contains(@class, "item")][' + time_calc + ']/span/text()'

def xweather( fcc, day, time ):
    return fcc.xpath(weather_xpath % (day, time))[0]

wk_map = {
    'ясно'            : None,
    'поземок'         : None,
    'малооблачно'     : 'c',
    'облачно'         : 'c',
    'пасмурно'        : 'c',
    'небольшой снег'  : 's',
    'снег'            : 's',
    'ледяные иглы'    : 's',
    'снегопад'        : 's',
    'небольшой дождь' : 'r',
    'дождь'           : 'r',
    'сильный дождь'   : 'r',
    'гроза'           : 'st'
}

wv_map = {
    'малооблачно'     : 1,
    'облачно'         : 2,
    'пасмурно'        : 4,
    'небольшой снег'  : 1,
    'снег'            : 2,
    'ледяные иглы'    : 2,
    'снегопад'        : 3,
    'небольшой дождь' : 1,
    'дождь'           : 2,
    'сильный дождь'   : 3,
}

def parse_weather( w ):
    res = {}
    arr = w.lower().split(',')

    for i in arr:
        i = i.strip()
        k = None
        v = None

        try:
            k = wk_map[i]
            if not k:
                continue
            v = wv_map.get(i, None)
            res[k] = v
        except KeyError:
            print('ERR: Invalid weather item \'%s\' in \'%s\'' % (i, w))
            quit()

    return res

def worst_weather( l ):
    res = {}

    for w in l:
        for i in w.items():
            key = i[0]
            val = i[1]
            prev = res.get(key, None)
            if not prev or prev < val:
                res[key] = val

    return res

def format_weather( w ):
    res = ''
    for i in w.items():
        res += i[0]
        if i[1]:
            res += str(i[1])
    return res

def _weather( fcc, day, time_rng ):
    ws = [parse_weather(xweather(fcc, day, t)) for t in time_rng]
    return format_weather(worst_weather(ws))


def print_fcast( fcc, day ):
    time_rng = range(2, 5) # Утро, День, Вечер

    d = _day(fcc, day)
    t = _temp(fcc, day, time_rng)
    w = _weather(fcc, day, time_rng)

    print('%s %d %s' % (d, t, w))

# main

# TODO handle 404
page = requests.get(link % city, headers={'user-agent': ua})
tree = html.fromstring(page.text)
fcc = get_fcc(tree, city)

# TODO handle xpath exceptions
print_fcast(fcc, 1)
print_fcast(fcc, 2)
print_fcast(fcc, 3)

