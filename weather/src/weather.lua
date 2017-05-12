require 'cairo'
rex = require 'rex_pcre'
utf8 = require 'utf8'

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
  -- local weather = 'Mon -3 s3c2\nTue 21 \nWed 0 c4r2st'
  local weather = conky_parse('${exec python ' .. path .. '/src/parse-gismeteo.py}')

  if not handle_error(cr, weather) then
    cairo_select_font_face(cr, f[1], CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, f[2])

    local ext = cairo_text_extents_t:create()
    tolua.takeownership(ext)

    local max_width = { total = 0 }
    cairo_text_extents(cr, '–', ext)
    max_width.n = ext.width
    cairo_text_extents(cr, '+', ext)
    max_width.p = ext.width

    local data = {}
    for d, t, w in rex.gmatch(weather, '(\\w+)\\s(-?\\d+)\\s([0-9rsct]*)') do
      table.insert(data, {day = d, temp = t, weather = parse_weather(w)})

      -- max_width.total calculated excluding numerical value of temp, only 'Wed–<sign>'
      cairo_text_extents(cr, text_dt(d, t), ext)
      max_width.total = math.max(max_width.total, ext.width)
    end
    ext = nil

    for i, fc in ipairs(data) do
      draw_weather(cr, 15, 2*37 - 37 * (i - 1), fc, max_width)
    end
  end

  cairo_pop_group_to_source(cr)
  cairo_paint(cr)

  cairo_destroy(cr)
  cairo_surface_destroy(cs)
end

function parse_weather(weather)
  res = {}
  for i, v in rex.gmatch(weather, '(st|[rsc])(\\d|)') do
    res[i] = v or true
  end
  return res
end

function handle_error(cr, weather)
  if weather:sub(1, 4) ~= 'ERR:' then
    return false
  end

  draw_img(cr, -12, 0, 'st', sun_rgba)

  cairo_select_font_face(cr, f_err[1], CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
  cairo_set_font_size(cr, f_err[2])
  set_rgba(cr, text_rgba)

  ml_text(cr, weather, 13, 0, w_width - 13, 1.5)

  return true
end

function ml_text(cr, txt, x, y, w, lr)
  local ext = cairo_text_extents_t:create()
  tolua.takeownership(ext)
  cairo_text_extents(cr, 'X', ext)

  local line = 1
  local t                    -- line text
  local lh = ext.height * lr -- line height

  for word in utf8.gmatch(txt, '%S+') do
    local i
    repeat
      i = 0
      local tt

      repeat
        i = i + 1
        tt = (t and (t .. ' ') or '') .. utf8.sub(word, 1, -i) .. (i > 1 and '-' or '')
        cairo_text_extents(cr, tt, ext)
      until t and utf8.len(tt) - utf8.len(t) <= 3
            or ext.width <= w

      if ext.width > w or i > 1 then
        cairo_move_to(cr, x, y + line * lh)
        line = line + 1

        if i > 1 and (not t or utf8.len(tt) - utf8.len(t) > 3) then
          cairo_show_text(cr, tt)
          word = utf8.sub(word, -i + 1, -1)
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

function text_dt(d, t)
  t = tonumber(t)
  local c = t < 0 and '–' or t > 0 and '+' or ''
  return string.format('%s–%s', d, c)
end

function text_t(t)
  return string.format('%+d', t):gsub('-', '–'):gsub('+0', '0')
end

function sign_w(w, temp)
  local t = tonumber(temp)
  return t < 0 and w.n or t > 0 and w.p or 0
end

i2color = {
  r  = rain_rgba,
  s  = snow_rgba,
  c  = clouds_rgba,
  st = storm_rgba
}

function draw_weather(cr, x, y, fc, mw)
  local day = fc.day
  local temp = fc.temp
  local w = fc.weather

  local ext = cairo_text_extents_t:create()
  tolua.takeownership(ext)
  set_rgba(cr, text_rgba)

  -- day

  cairo_text_extents(cr, day, ext)
  local yt = y + 16 + ext.height / 2
  cairo_move_to(cr, x + 40, yt)
  cairo_show_text(cr, day)

  -- temp

  cairo_move_to(cr, x + 40 + mw.total - sign_w(mw, temp), yt)
  cairo_show_text(cr, text_t(temp))

  -- construct icon

  cairo_push_group(cr)

  if w.r and w.s then
    if w.s > w.r then
      w.r = nil
    else
      w.s = nil
    end
  end

  local off = (w.r or w.s) and 0 or 4

  -- sun

  draw_img(cr, x, y + off, 'sun', sun_rgba)

  -- precipitation

  for i, v in pairs(w) do
    if i == 'r' or i == 's' then
      local xx = x + 15 + (w.r and 1 or 0) - v * 4
      local yy = y + 23

      for j = 0, v-1 do draw_img(cr, xx + j * 8, yy, i, i2color[i]) end
    end
  end

  -- clouds

  if w.c then
    local i = 'c' .. tonumber(w.c)
    local yy = y + off

    draw_img(cr, x, yy, i .. '-b', nil)
    draw_img(cr, x, yy, i, clouds_rgba)
  end

  -- storm

  if w.st then
    local xx = x - 1
    local yy = y + off - 2

    draw_img(cr, xx, yy, 'st' .. '-b', nil)
    draw_img(cr, xx, yy, 'st', storm_rgba)
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

