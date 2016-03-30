#!/usr/bin/python

import sys
import re
from os import path, listdir
from mpd import MPDClient

# Here goes all the settings

mpd_host = 'localhost'
mpd_port = 6600
mpd_dir = '/media/music/'
cover_pat = re.compile('(cover|folder)\.(jpe?g|png)', re.I)
no_cover_file = ''
no_album = 'No Album'

c = MPDClient()
c.connect(mpd_host, mpd_port)
status = c.status()
song = c.currentsong()
c.close()
c.disconnect()

if status and status['state'] == 'stop':
    sys.exit()

if song:
    cover = None
    p = mpd_dir + path.dirname(song['file'])
    for f in listdir(p):
        tmp = p + '/' + f
        if cover_pat.fullmatch(f) and path.isfile(tmp):
            cover = tmp
            break
    print(cover if cover else no_cover_file)
    artist = song.get('artist')
    title = song.get('title')
    print('{}{}'.format(
        artist + ' – ' if artist else '',
        title if title else path.basename(song['file'])))
    date = song.get('date')
    album = song.get('album')
    print('{}{}'.format(
        album if album else no_album,
        ' (' + date + ')' if date else ''))
    t = status['time'].split(':')
    print(round(float(t[0])/float(t[1])*100)/100)
