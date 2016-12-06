require 'cairo'
rex = require 'rex_pcre'

w_width, w_height = 120, 100

-- Widget path
path = '/home/yonigger/.config/conky/weather'

-- Font
f = {'Noto Sans', 13}
f_err = {'lemon', 10}

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

  cairo_push_group(cr)
  -- TODO http://w3.impa.br/~diego/software/luasocket & http://luaxpath.luaforge.net
  -- 'Sat -13 s3c4\nSun 2 r3c3st\nMon 39 c1'
  local weather = conky_parse('${exec python ' .. path .. '/src/parse-gismeteo.py}')

  if not handle_error(cr, weather) then
    cairo_select_font_face(cr, f[1], CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, f[2])

    local i = 0
    -- TODO justify temperatures
    for day, temp, w in rex.gmatch(weather, '(\\w+)\\s(-?\\d+)\\s([0-9rsct]*)') do
      draw_weather(cr, 15, 2*37 - 37 * i, day, temp, w)
      i = i + 1
    end
  end

  cairo_pop_group_to_source(cr)
  cairo_paint(cr)

  cairo_destroy(cr)
  cairo_surface_destroy(cs)
end

function handle_error(cr, weather)
  if weather:sub(1, 4) ~= 'ERR:' then
    return false
  end

  draw_img(cr, -12, 0, 'st', sun_rgba)

  cairo_select_font_face(cr, f_err[1], CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
  cairo_set_font_size(cr, f_err[2])
  set_rgba(cr, text_rgba)

  ml_text(cr, weather, 13, 0, w_width - 15, 1.5) -- strange magic on 'w_width - 13'

  return true
end

function ml_text(cr, txt, x, y, w, lr)
  local ext = cairo_text_extents_t:create()
  tolua.takeownership(ext)
  cairo_text_extents(cr, 'X', ext)

  local line = 1
  local t                    -- line text
  local lh = ext.height * lr -- line height

  for word in txt:gmatch('%S+') do
    local i
    repeat
      i = 0
      local tt

      repeat
        i = i + 1
        tt = (t and (t .. ' ') or '') .. word:sub(1, -i)
        cairo_text_extents(cr, tt, ext)
      until (t and t:len() == tt:len() - 1) or ext.width <= w

      if ext.width > w or i > 1 then
        cairo_move_to(cr, x, y + line * lh)
        line = line + 1

        if i > 1 and (not t or tt:len() - t:len() > 2) then
          cairo_show_text(cr, tt)
          word = word:sub(-i + 1, -1)
        else
          cairo_show_text(cr, t)
        end

        t = nil
        i = -1
      else
        t = tt
      end
    until i == 1
  end

  -- residues
  cairo_move_to(cr, x, y + line * lh)
  cairo_show_text(cr, t)
end

w2c = {
  r = rain_rgba,
  s = snow_rgba,
  c = clouds_rgba
}

function draw_weather(cr, x, y, day, temp, w)
  -- text

  local text = string.format('%s  %+d', day, temp):gsub('-', '–'):gsub('+0', '0')
  local ext = cairo_text_extents_t:create()

  tolua.takeownership(ext)
  set_rgba(cr, text_rgba)
  cairo_text_extents(cr, text, ext)
  cairo_move_to(cr, x + 40 - ext.x_bearing, y + 16 + ext.height / 2)
  cairo_show_text(cr, text)

  -- construct icon

  cairo_push_group(cr)

  local off = rex.find(w, '[sr]\\d') and 0 or 4
  draw_img(cr, x, y + off, 'sun', sun_rgba)

  for m in rex.gmatch(w, 'st|[rsc]\\d') do
    local yy = y
    local ch = m:sub(1,1)
    local c = m == 'st' and storm_rgba or w2c[ch]

    if ch == 'c' then
      yy = yy + off
    end

    if m == 'st' or ch == 'c' then
      draw_img(cr, x, yy, m .. '-b', nil)
    end

    draw_img(cr, x, yy, m, c)
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

