require 'cairo'
bit = require 'bit'

-- Widget path
path = '/home/yonigger/.config/conky/cpu'

-- Font
f = {'lemon', 10}

-- Colors
mc = {0.4, 0.35, 0.36, 1}
ac = {0.8, 0.3, 0.2, 1}

text = 'i7-4790K'

function conky_main()
	if conky_window == nil then return end

	-- init
	local cs = cairo_xlib_surface_create(conky_window.display,
		conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
	local cr = cairo_create(cs)

	-- background
	cairo_push_group(cr)
	local mask = cairo_image_surface_create_from_png(path .. '/img/cpu.png')
	cairo_set_source_surface(cr, mask, 0, 0)
	cairo_paint(cr)
	cairo_surface_destroy(mask)

	-- colorize
	cairo_set_operator(cr, CAIRO_OPERATOR_IN)
	set_rgba(cr, mc)
	cairo_paint(cr)

	cairo_set_operator(cr, CAIRO_OPERATOR_OVER)

	-- top text
	cairo_select_font_face(cr, f[1], CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
	cairo_set_font_size(cr, f[2])
	cairo_move_to(cr, 11, 20)
	cairo_show_text(cr, text)

	-- bottom text
	local i = math.floor(conky_parse('${updates}') / 20) % 4
	local temp = get_temp(i + 1)
	local ext = cairo_text_extents_t:create()
	cairo_text_extents(cr, temp, ext)
	cairo_move_to(cr, 31 - ext.x_bearing - math.floor(ext.width / 2), 53)
	tolua.takeownership(ext)
	cairo_show_text(cr, temp)

	-- load bars
	for i = 1, 8, 1 do
		local pos_x = 12 + 5 * (i - 1)
		local full = true -- accentuate full core usage
		local cpu = get_cpu(i)

		for j = 0, 3, 1 do
			if bit.band(cpu, bit.lshift(1, j)) == 0 then
				full = false
			else
				cairo_rectangle(cr, pos_x, 39 - 5 * j, 4, 4)
			end
		end
		
		set_rgba(cr, full and ac or mc)
		cairo_fill(cr)
	end

	cairo_pop_group_to_source(cr)
	cairo_paint(cr)

	-- clear
	cairo_destroy(cr)
	cairo_surface_destroy(cs)
end

function set_rgba(cr, c)
	cairo_set_source_rgba(cr, c[1], c[2], c[3], c[4])
end

function get_temp(num)
	return conky_parse('${hwmon 1 temp ' .. num .. '}°C')
end

function get_cpu(num)
	return math.floor(conky_parse('${cpu cpu' .. num .. '}') / 100 * 15 + 0.5)
end
