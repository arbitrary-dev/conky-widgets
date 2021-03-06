require 'cairo'
require 'imlib2'
require 'cairo_imlib2_helper'
utf8 = require 'utf8'

-- Widget path
path = '/home/yonigger/.config/conky/mpd'

-- Font
f = {'Noto Sans', 13}

-- Colors
mc = {0.4, 0.35, 0.36, 1}
ac = {0.8, 0.3, 0.2, 1}

upd_int = 0.5
w, h = 256, 256
time_size = 3
info_size = 22
noalbum_title = ''

function conky_main()
	-- TODO https://github.com/kAworu/lua-mpd
	-- get song
	local song = split(conky_parse('${exec ' .. path .. '/src/get-song.py}'), '\r?\n')
	-- TODO slow down updates on pause
	if not (song[2] and conky_window) then
		conky_set_update_interval(upd_int * 10)
		return
	end

	conky_set_update_interval(upd_int)

	-- init
	local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
		conky_window.visual, conky_window.width, conky_window.height)
	local cr = cairo_create(cs)

	draw_img(cr, song[1])
	draw_info(cr, song)

	cairo_destroy(cr)
	cairo_surface_destroy(cs)
end

function draw_img(cr, img)
	if img == '' then
		return
	end
	
	cairo_push_group(cr)

	if cover ~= img then
		cover = img
		ccolor = nil

		-- compute scaling
		imlib_context_set_image(imlib_load_image(img))
		iw, ih = imlib_image_get_width(), imlib_image_get_height()
		imlib_free_image()
		local s = math.ceil(math.max(w / iw, h / ih) * 100) / 100
		sw = math.ceil(iw * s) / iw
		sh = math.ceil(ih * s) / ih
	end
	
	-- draw scaled
	local cs = cairo_image_surface_create(CAIRO_FORMAT_RGB24, w, h)
	cairo_draw_image(img, cs,
		math.floor((w-sw*iw)/2+0.5),
		math.floor((h-sw*ih)/2+0.5),
		sw, sh, 0, 0)
	cairo_set_source_surface(cr, cs, 0, 0)
	cairo_paint_with_alpha(cr, 0.65)
	cairo_surface_destroy(cs)

	-- little gradient on cover bottom
	local pat = cairo_pattern_create_linear(0, h, 0.1, h - 12)
	local sc = l(mc, 0.5)
	cairo_pattern_add_color_stop_rgba(pat, 0.3, sc[1], sc[2], sc[3], 0.3)
	cairo_pattern_add_color_stop_rgba(pat, 1, sc[1], sc[2], sc[3], 0)
	cairo_set_source(cr, pat)
	cairo_rectangle(cr, 0, 0, w, h)
	cairo_fill(cr)
	cairo_pattern_destroy(pat)

	-- shadow
	cairo_push_group(cr)
	local mask = cairo_image_surface_create_from_png(path .. '/img/mask.png')
	cairo_set_source_surface(cr, mask, 14, h - 42)
	cairo_set_operator(cr, CAIRO_OPERATOR_OVER)
	cairo_paint(cr)
	cairo_set_operator(cr, CAIRO_OPERATOR_IN)
	set_rgba_(cr, sc, 0.3)
	cairo_paint(cr)
	cairo_pop_group_to_source(cr)
	cairo_rectangle(cr, 0, 0, w, h)
	cairo_fill(cr)

	-- mask
	cairo_set_operator(cr, CAIRO_OPERATOR_DEST_OUT)
	cairo_set_source_surface(cr, mask, 0, h - 47)
	cairo_paint(cr)
	cairo_surface_destroy(mask)

	cairo_pop_group_to_source(cr)
	cairo_paint(cr)
end

function draw_info(cr, song)
	local y = h + info_size + 13

	-- timeline
	local elapsed, total = song[4]:match('([^:]+):([^:]+)')
	set_rgba_(cr, ac, 0.3)
	cairo_move_to(cr, 0, y - info_size)
	cairo_rel_line_to(cr, 0, time_size)
	cairo_rel_line_to(cr, w, 0)
	cairo_rel_line_to(cr, 0, -time_size)
	cairo_close_path(cr)
	cairo_fill(cr)

	-- time
	set_rgba(cr, ac)
	cairo_move_to(cr, 0, y - info_size)
	cairo_rel_line_to(cr, 0, time_size)
	cairo_rel_line_to(cr, math.floor(elapsed * w / total + 0.5), 0)
	cairo_rel_line_to(cr, 0, -time_size)
	cairo_close_path(cr)
	cairo_fill(cr)

	-- song & album
	cairo_select_font_face(cr, f[1], CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
	cairo_set_font_size(cr, f[2])
	set_rgba(cr, mc)
	-- TODO no album handling
	-- TODO slow down updates on pause
	local txt = trunc(
		(song[3] == noalbum_title or elapsed % 16 < 8) and song[2] or song[3],
		elapsed % 8 < 4, w - 10, cr, '…')
	local ext = cairo_text_extents_t:create()
	tolua.takeownership(ext)
	cairo_text_extents(cr, txt, ext)
	cairo_move_to(cr, w / 2 - ext.x_bearing - ext.width / 2, y - 6)
	cairo_show_text(cr, txt)

	-- TODO output playback status (repeat, single, random) on barrel
end

function trunc(s, r, w, cr, e)
	local str = trim(s)
	local res = str

	local ext = cairo_text_extents_t:create()
	tolua.takeownership(ext)
	cairo_text_extents(cr, str, ext)

	while ext.width > w do
		str = r and utf8.sub(str, 1, -2) or utf8.sub(str, 2)
		str = trim(str)
		res = r and str .. ' ' .. e or e .. ' ' .. str
		
		cairo_text_extents(cr, res, ext)
	end

	return res
end

function split(str, sep)
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub('(.-)' .. sep, helper)))
	return t
end

function l(c, m)
	return {math.min(1, c[1]*m), math.min(1, c[2]*m), math.min(1, c[3]*m), c[4]}
end

function set_rgba_(cr, c, a)
	cairo_set_source_rgba(cr, c[1], c[2], c[3], a)
end

function set_rgba(cr, c)
	cairo_set_source_rgba(cr, c[1], c[2], c[3], c[4])
end

function trim(s)
	local n = utf8.find(s, '%S')
	return n and utf8.match(s, '.*%S', n) or ''
end
