require 'cairo'

-- Widget path
path = '/home/yonigger/.config/conky/ram'

-- Font
f = {'lemon', 10}

-- Colors
mc = {0.4, 0.35, 0.36, 1}
ac = {0.8, 0.3, 0.2, 1}

function conky_main()
	-- init
	local cs = cairo_xlib_surface_create(conky_window.display,
		conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
	local cr = cairo_create(cs)

	-- background
	cairo_push_group(cr)
	local mask = cairo_image_surface_create_from_png(path .. '/img/ram.png')
	cairo_set_source_surface(cr, mask, 0, 0)
	cairo_paint(cr)
	cairo_surface_destroy(mask)

	-- colorize
	cairo_set_operator(cr, CAIRO_OPERATOR_IN)
	set_rgba(cr, mc)
	cairo_paint(cr)

	-- ram value
	cairo_select_font_face(cr, f[1], CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
	cairo_set_font_size(cr, f[2])
	local mem = conky_parse('${mem}')
	local ram = tonumber(string.sub(mem, 1, -4))
	ram = string.sub(mem, -3) == 'MiB' and ram or ram * 1024
	local ram_str = get_ram(ram)
	local ext = cairo_text_extents_t:create()
	tolua.takeownership(ext)
	cairo_text_extents(cr, ram_str, ext)
	local x, y = 32 - ext.x_bearing - math.floor(ext.width / 2), 35

	-- crop space for ram
	cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR)
	cairo_rectangle(cr, x - 1, y - ext.height - 1, ext.width + 3 + ext.x_bearing, ext.height + 2)
	cairo_fill(cr)

	-- draw it
	cairo_set_operator(cr, CAIRO_OPERATOR_OVER)
	cairo_move_to(cr, x, y)
	cairo_show_text(cr, ram_str)

	-- ram bars
	local bars = math.ceil(ram / 512) - 1
	for s = 0, bars, 1 do
		local i = s % 8
		local j = math.floor(s / 8)
		cairo_rectangle(cr,
			4 + 7 * i + (i < 4 and 0 or 3),
			53 - 16 * j - (j < 2 and 0 or 2),
			4, 7)

		-- accentuate 4G
		if i == 7 then
			set_rgba(cr, ac)
			cairo_fill(cr)
		end
	end
	set_rgba(cr, mc)
	cairo_fill(cr)

	cairo_pop_group_to_source(cr)
	cairo_paint(cr)

	cairo_destroy(cr)
	cairo_surface_destroy(cs)
end

function set_rgba(cr, c)
	cairo_set_source_rgba(cr, c[1], c[2], c[3], c[4])
end

function get_ram(ram)
	if ram < 1000 then
		return ram .. 'MB'
	end
	return (math.floor(ram / 102.4 + 0.5) / 10) .. 'GB'
end
