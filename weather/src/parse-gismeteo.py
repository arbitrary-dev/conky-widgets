#!/usr/bin/python

from lxml import html
import requests

# settings

city = '4476'
link = 'https://www.gismeteo.ru/weather-perm-%s/hourly'
ua = 'Mozilla/5.0 (X11; Linux x86_64; rv:41.0) Gecko/20100101 Firefox/41.0'

# day

day_xpath = 'div[contains(@class, "frame_header")]/div[contains(@class, "item")][%d]/span/text()'

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

def get_day( fcc, day ):
    return d_map[xday(fcc, day)[:2].lower()]

# temperature

temp_xpath = 'div[contains(@class, "templine")]/div/div[contains(@class, "item")][(%d-1)*8+%d]/@data-air'

def xtemp( fcc, day, time ):
    return fcc.xpath(temp_xpath % (day, time))[0]

def get_temp( t ):
    return int(t)

def avg_temp( l ):
    return round(sum(l) / len(l))

# weather

weather_xpath = 'div[contains(@class, "iconline")]/div[contains(@class, "item")][(%d-1)*8+%d]/span/text()'

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
    'снегопад'        : 3,
    'небольшой дождь' : 1,
    'дождь'           : 2,
    'сильный дождь'   : 3,
}

def get_weather( w ):
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

def print_fcast( fcc, d ):
    day = get_day(fcc, d)

    time_rng = range(3, 8)

    ts = [get_temp(xtemp(fcc, d, t)) for t in time_rng]
    temp = avg_temp(ts)

    ws = [get_weather(xweather(fcc, d, t)) for t in time_rng]
    weather = format_weather(worst_weather(ws))

    print('%s %d %s' % (day, temp, weather))

fcc_xpath = '//div[contains(@class, "forecast_container")]'

def get_fcc(city):
    page = requests.get(link % city, headers={'user-agent': ua})
    tree = html.fromstring(page.text)
    return tree.xpath(fcc_xpath)[0]

fcc = get_fcc(city)

print_fcast(fcc, 1)
print_fcast(fcc, 2)
print_fcast(fcc, 3)

