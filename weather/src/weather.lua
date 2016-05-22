require 'cairo'
rex = require 'rex_pcre'

-- Widget path
path = '/home/yonigger/.config/conky/weather'

-- Font
f = {'Noto Sans', 13}

-- Colors
text_rgba = {0.4, 0.35, 0.36, 1}
sun_rgba = {0.8, 0.3, 0.2, 1} -- {1.00, 0.87, 0.50, 1}
clouds_rgba = {0.4, 0.35, 0.36, 1} -- {0.7, 0.7, 0.7, 1}
snow_rgba = {0.4, 0.35, 0.36, 1} -- {1, 1, 1, 1}
rain_rgba = {0.4, 0.35, 0.36, 1} -- {0.56, 0.76, 0.89, 1}
storm_rgba = {0.4, 0.35, 0.36, 1}

function conky_main()
	if conky_window == nil then return end

	-- init
	local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
		conky_window.visual, conky_window.width, conky_window.height)
	local cr = cairo_create(cs)
	cairo_select_font_face(cr, f[1], CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
	cairo_set_font_size(cr, f[2])

	cairo_push_group(cr)
	-- TODO http://w3.impa.br/~diego/software/luasocket & http://luaxpath.luaforge.net
	-- 'Sat –13 s4c3;Sun +2 r4c4st;Mon +39 c1'
	local weather = conky_parse('${exec python ' .. path .. '/src/parse-gismeteo.p}')
	local i = 0
	-- TODO update forecast for current day according to time
	-- TODO justify temperatures
	for day, temp, w in rex.gmatch(weather, '(\\w+)\\s(.+?)\\s([0-9rsct]*)') do
		draw_weather(cr, 0, 2*37 - 37 * i, day, temp, w)
		i = i + 1
	end
	cairo_pop_group_to_source(cr)
	cairo_paint(cr)

	cairo_destroy(cr)
	cairo_surface_destroy(cs)
end

function draw_weather(cr, x, y, day, temp, w)
	-- text
	set_rgba(cr, text_rgba)
	local text = string.format('%s  %s°C', day, temp)
	local ext = cairo_text_extents_t:create()
	tolua.takeownership(ext)
	cairo_text_extents(cr, text, ext)
	cairo_move_to(cr, 40 - ext.x_bearing, y + 16 + ext.height / 2)
	cairo_show_text(cr, text)

	-- construct icon
	local r, s, c, st = rex.match(w, '(r\\d){0,1}(s\\d){0,1}(c\\d){0,1}(st){0,1}')
	local off = (r or s) and 0 or 4
	cairo_push_group(cr)
	draw_img(cr, x, y + off, 'sun', sun_rgba)
	if r then
		draw_img(cr, x, y, r, rain_rgba)
	end
	if s then
		draw_img(cr, x, y, s, snow_rgba)
	end
	if c then
		draw_img(cr, x, y + off, c .. '-b', nil)
		draw_img(cr, x, y + off, c, clouds_rgba)
	end
	if st then
		draw_img(cr, x, y, st .. '-b', nil)
		draw_img(cr, x, y, st, storm_rgba)
	end
	cairo_pop_group_to_source(cr)

	cairo_set_operator(cr, CAIRO_OPERATOR_OVER)
	cairo_paint(cr)
end

function draw_img(cr, x, y, img, rgba)
	if rgba then
		cairo_push_group(cr)
		set_rgba(cr, rgba)
		cairo_set_operator(cr, CAIRO_OPERATOR_OVER)
		cairo_paint(cr)
		cairo_set_operator(cr, CAIRO_OPERATOR_DEST_IN)
	else
		-- use '*-b.png' image variant to clear items on bottom
		cairo_set_operator(cr, CAIRO_OPERATOR_DEST_OUT)
	end

	local s = cairo_image_surface_create_from_png(
		path .. '/img/' .. img .. '.png')
	cairo_set_source_surface(cr, s, x, y)
	cairo_paint(cr)
	cairo_surface_destroy(s)

	-- colorize
	if rgba then
		cairo_pop_group_to_source(cr)
		cairo_set_operator(cr, CAIRO_OPERATOR_OVER)
		cairo_paint(cr)
	end
end

function set_rgba(cr, c)
	cairo_set_source_rgba(cr, c[1], c[2], c[3], c[4])
end
