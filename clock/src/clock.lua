require 'cairo'

-- Widget path
path = '/home/yonigger/.config/conky/clock' 

-- Fonts
ft = {'Noto Sans', 120}
fd = {'Noto Sans', 15}

-- Colors
grad1 = {1, 0.82, 0.53, 1}
grad2 = {0.6, 0.57, 0.6, 1}
grad3 = {0.25, 0.25, 0.25, 1}
shd = {0.4, 0.35, 0.36, 1}

function conky_main()
  if conky_window == nil then return end

  -- init
  local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
    conky_window.visual, conky_window.width, conky_window.height)
  local cr = cairo_create(cs)

  -- mask
  cairo_push_group(cr)
  local w, h = 315, 130 -- mask size
  local off = 20
  local mask = cairo_image_surface_create_from_png(path .. '/img/mask.png')
  cairo_set_source_surface(cr, mask, off, 0)
  cairo_paint(cr)
  cairo_surface_destroy(mask)

  -- time
  cairo_push_group(cr)
  local time = conky_parse('${time %R}')
  cairo_select_font_face(cr, ft[1], CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
  cairo_set_font_size(cr, ft[2])
  local ext = cairo_text_extents_t:create()
  tolua.takeownership(ext)
  cairo_text_extents(cr, time, ext)
  local tx, ty = off + 9 - ext.x_bearing, h - 10

  -- shade
  set_rgba(cr, shd)
  cairo_move_to(cr, tx + 2, ty + 1)
  cairo_show_text(cr, time)

  -- foreground
  local pat = cairo_pattern_create_radial(60, -220, 2*h, 150, -380, 3.9*h)
  set_stop(pat, 0,	l(grad1, 1.4))
  set_stop(pat, 0.3,	grad1)
  set_stop(pat, 0.75,	grad2)
  set_stop(pat, 1,	grad3)
  cairo_set_source(cr, pat)
  cairo_move_to(cr, tx, ty)
  cairo_show_text(cr, time)
  cairo_pattern_destroy(pat)

  cairo_pop_group_to_source(cr)
  cairo_set_operator(cr, CAIRO_OPERATOR_IN)
  cairo_paint(cr)
  cairo_pop_group_to_source(cr)
  cairo_paint(cr)

  -- date
  set_rgba(cr, l(grad1, 1.4))
  cairo_set_operator(cr, CAIRO_OPERATOR_OVER)
  local day = tonumber(os.date('%d'))
  local suff = {[0] = 'th', 'st', 'nd', 'rd', 'th'}
  day = day .. suff[(day == 11 or day == 12) and 0 or math.min(day%10, 4)]
  local date = conky_parse('${time %A, ' .. day .. ' %B}')
  cairo_select_font_face(cr, fd[1], CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
  cairo_set_font_size(cr, fd[2])
  cairo_text_extents(cr, date, ext)
  local tx, ty = off + 190 - ext.width, ty + 20
  cairo_move_to(cr, tx, ty)
  cairo_show_text(cr, date)

  -- clear
  cairo_destroy(cr)
  cairo_surface_destroy(cs)
end

function l(c, m)
  return {math.min(1, c[1]*m), math.min(1, c[2]*m), math.min(1, c[3]*m), c[4]}
end

function set_rgba(cr, c)
  cairo_set_source_rgba(cr, c[1], c[2], c[3], c[4])
end

function set_stop(pat, pos, c)
  cairo_pattern_add_color_stop_rgba(pat, pos, c[1], c[2], c[3], c[4])
end

