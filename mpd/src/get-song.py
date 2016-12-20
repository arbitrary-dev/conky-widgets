#!/usr/bin/python

import sys
import re
from os import path, listdir
from mpd import MPDClient

# settings

mpd_host = 'localhost'
mpd_port = 6600
mpd_dir = '/media/music/'
cover_pat = re.compile('.*(cover|folder|front).*\.(jpe?g|png)$', re.I)
no_cover_file = ''
no_album = ''

# helpers

def get(song, what):
    res = song.get(what);
    if isinstance(res, list):
        res = res[0]
    return res

# main

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
    cover_pat_song = re.compile(
        path.splitext(path.basename(song['file']))[0] + '\.(jpe?g|png)', re.I)
    for f in listdir(p):
        tmp = p + '/' + f
        if (cover_pat.fullmatch(f) or cover_pat_song.fullmatch(f)) and path.isfile(tmp):
            cover = tmp
            break
    print(cover if cover else no_cover_file)
    artist = get(song, 'artist')
    title = (get(song, 'title') or '').strip()
    if title:
        print('{}{}'.format(artist + ' – ' if artist else '', title))
    else:
        print(path.basename(song['file']))
    date = get(song, 'date')
    album = (get(song, 'album') or no_album).strip()
    if album:
        print('{}{}'.format(album, ' (' + date + ')' if date else ''))
    else:
        print('')
    print(status['time'])
