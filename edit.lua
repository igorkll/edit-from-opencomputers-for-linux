#!/usr/bin/lua5.3
local home_dir = os.getenv("HOME")
local config_dir_path = home_dir .. "/.config"
local config_path = config_dir_path .. "/edit.cfg"

-------------------------------- functions

local function checkArg(n, have, ...)
  have = type(have)
  local function check(want, ...)
    if not want then
      return false
    else
      return have == want or check(...)
    end
  end
  if not check(...) then
    local msg = string.format("bad argument #%d (%s expected, got %s)",
                              n, table.concat({...}, " or "), have)
    error(msg, 3)
  end
end

-------------------------------- unicode

-- Pure Lua implementation of the OpenComputers unicode library.
-- Requires Lua 5.3+ with the built-in utf8 library.
-- All functions return (result) on success, or (nil, error_message) on failure,
-- emulating the behaviour of the original spcall-wrapped version.

local utf8 = require("utf8")

-- ----------------------------------------------------------------------
-- Wide character ranges (East Asian Width = W or F, plus common CJK blocks)
-- This table is used by isWide() and charWidth().
-- ----------------------------------------------------------------------
local wide_ranges = {
    {0x1100, 0x115F},   -- Hangul Jamo
    {0x2329, 0x232A},   -- Angle brackets
    {0x2E80, 0x2EFF},   -- CJK Radicals Supplement
    {0x2F00, 0x2FDF},   -- Kangxi Radicals
    {0x2FF0, 0x2FFF},   -- Ideographic Description Characters
    {0x3000, 0x303F},   -- CJK Symbols and Punctuation
    {0x3040, 0x309F},   -- Hiragana
    {0x30A0, 0x30FF},   -- Katakana
    {0x3100, 0x312F},   -- Bopomofo
    {0x3130, 0x318F},   -- Hangul Compatibility Jamo
    {0x3190, 0x319F},   -- Kanbun
    {0x31A0, 0x31BF},   -- Bopomofo Extended
    {0x31C0, 0x31EF},   -- CJK Strokes
    {0x31F0, 0x31FF},   -- Katakana Phonetic Extensions
    {0x3200, 0x32FF},   -- Enclosed CJK Letters and Months
    {0x3300, 0x33FF},   -- CJK Compatibility
    {0x3400, 0x4DBF},   -- CJK Unified Ideographs Extension A
    {0x4E00, 0x9FFF},   -- CJK Unified Ideographs
    {0xA000, 0xA4CF},   -- Yi Syllables
    {0xAC00, 0xD7AF},   -- Hangul Syllables
    {0xF900, 0xFAFF},   -- CJK Compatibility Ideographs
    {0xFE10, 0xFE1F},   -- Vertical Forms
    {0xFE30, 0xFE4F},   -- CJK Compatibility Forms
    {0xFF00, 0xFFEF},   -- Halfwidth and Fullwidth Forms (Fullwidth part)
    {0x1B000, 0x1B0FF}, -- Kana Supplement
    {0x1B100, 0x1B12F}, -- Kana Extended-A
    {0x1F200, 0x1F2FF}, -- Enclosed Ideographic Supplement
    {0x20000, 0x2A6DF}, -- CJK Unified Ideographs Extension B
    {0x2A700, 0x2B73F}, -- Extension C
    {0x2B740, 0x2B81F}, -- Extension D
    {0x2B820, 0x2CEAF}, -- Extension E
    {0x2CEB0, 0x2EBEF}, -- Extension F
    {0x2F800, 0x2FA1F}, -- CJK Compatibility Ideographs Supplement
}

-- Helper: check if a codepoint is wide
local function is_codepoint_wide(cp)
    for _, range in ipairs(wide_ranges) do
        if cp >= range[1] and cp <= range[2] then
            return true
        end
    end
    return false
end

-- ----------------------------------------------------------------------
-- Public functions
-- ----------------------------------------------------------------------

local unicode = {}

-- char(...) -> string
function unicode.char(...)
    local ok, res = pcall(utf8.char, ...)
    if ok then
        return res
    else
        return nil, res
    end
end

-- len(s) -> number of codepoints
function unicode.len(s)
    local ok, res = pcall(utf8.len, s)
    if ok then
        return res
    else
        return nil, res
    end
end

-- lower(s) -> lowercase string (ASCII only; non‑ASCII unchanged)
function unicode.lower(s)
    if type(s) ~= "string" then
        return nil, "bad argument #1 to 'lower' (string expected)"
    end
    local parts = {}
    for cp in utf8.codes(s) do
        if cp >= 65 and cp <= 90 then        -- A-Z
            cp = cp + 32
        end
        table.insert(parts, utf8.char(cp))
    end
    return table.concat(parts)
end

-- upper(s) -> uppercase string (ASCII only; non‑ASCII unchanged)
function unicode.upper(s)
    if type(s) ~= "string" then
        return nil, "bad argument #1 to 'upper' (string expected)"
    end
    local parts = {}
    for cp in utf8.codes(s) do
        if cp >= 97 and cp <= 122 then       -- a-z
            cp = cp - 32
        end
        table.insert(parts, utf8.char(cp))
    end
    return table.concat(parts)
end

-- reverse(s) -> reversed string by codepoint, not by byte
function unicode.reverse(s)
    if type(s) ~= "string" then
        return nil, "bad argument #1 to 'reverse' (string expected)"
    end
    local chars = {}
    for cp in utf8.codes(s) do
        table.insert(chars, utf8.char(cp))
    end
    -- reverse the table
    local n = #chars
    for i = 1, n // 2 do
        chars[i], chars[n - i + 1] = chars[n - i + 1], chars[i]
    end
    return table.concat(chars)
end

-- sub(s, i, j) -> substring from codepoint index i to j (like string.sub)
function unicode.sub(s, i, j)
    if type(s) ~= "string" then
        return nil, "bad argument #1 to 'sub' (string expected)"
    end
    local n = utf8.len(s)
    if n == nil then
        return nil, "invalid UTF-8 string"
    end
    if i == nil then i = 1 end
    if j == nil then j = -1 end

    -- normalise indices (same logic as string.sub)
    if i < 0 then i = n + i + 1 end
    if j < 0 then j = n + j + 1 end
    if i < 1 then i = 1 end
    if j > n then j = n end

    if i > n or j < 1 or i > j then
        return ""
    end

    local start_byte = utf8.offset(s, i)
    if not start_byte then
        return nil, "invalid UTF-8 string"
    end
    local end_byte
    if j < n then
        end_byte = utf8.offset(s, j + 1) - 1
    else
        end_byte = #s
    end
    return string.sub(s, start_byte, end_byte)
end

-- isWide(s) -> true if the first (and only) character in s is wide
function unicode.isWide(s)
    if type(s) ~= "string" then
        return nil, "bad argument #1 to 'isWide' (string expected)"
    end
    local cp
    local ok, err = pcall(utf8.codepoint, s)
    if not ok then
        return nil, err
    end
    cp = err
    -- ensure exactly one codepoint
    local _, count = string.gsub(s, "[\x80-\xBF]", "") -- count continuation bytes
    if utf8.len(s) ~= 1 then
        return nil, "string must contain exactly one character"
    end
    return is_codepoint_wide(cp)
end

-- charWidth(s) -> 2 if wide, 1 otherwise
function unicode.charWidth(s)
    local ok, wide = unicode.isWide(s)
    if not ok then
        return nil, wide   -- wide holds the error message
    end
    return wide and 2 or 1
end

-- wlen(s) -> total display width
function unicode.wlen(s)
    if type(s) ~= "string" then
        return nil, "bad argument #1 to 'wlen' (string expected)"
    end
    local total = 0
    for cp in utf8.codes(s) do
        total = total + (is_codepoint_wide(cp) and 2 or 1)
    end
    return total
end

-- wtrunc(s, n) -> truncate s to at most n display width
function unicode.wtrunc(s, n)
    if type(s) ~= "string" then
        return nil, "bad argument #1 to 'wtrunc' (string expected)"
    end
    if type(n) ~= "number" then
        return nil, "bad argument #2 to 'wtrunc' (number expected)"
    end
    if n < 0 then
        return nil, "width must be non-negative"
    end
    local result = {}
    local width = 0
    for cp in utf8.codes(s) do
        local cw = is_codepoint_wide(cp) and 2 or 1
        if width + cw > n then
            break
        end
        width = width + cw
        table.insert(result, utf8.char(cp))
    end
    return table.concat(result)
end

-------------------------------- serialization

local serialization = {}

-- delay loaded tables fail to deserialize cross [C] boundaries (such as when having to read files that cause yields)
local local_pairs = function(tbl)
  local mt = getmetatable(tbl)
  return (mt and mt.__pairs or pairs)(tbl)
end

-- Important: pretty formatting will allow presenting non-serializable values
-- but may generate output that cannot be unserialized back.
function serialization.serialize(value, pretty)
  local kw =  {["and"]=true, ["break"]=true, ["do"]=true, ["else"]=true,
               ["elseif"]=true, ["end"]=true, ["false"]=true, ["for"]=true,
               ["function"]=true, ["goto"]=true, ["if"]=true, ["in"]=true,
               ["local"]=true, ["nil"]=true, ["not"]=true, ["or"]=true,
               ["repeat"]=true, ["return"]=true, ["then"]=true, ["true"]=true,
               ["until"]=true, ["while"]=true}
  local id = "^[%a_][%w_]*$"
  local ts = {}
  local result_pack = {}
  local function recurse(current_value, depth)
    local t = type(current_value)
    if t == "number" then
      if current_value ~= current_value then
        table.insert(result_pack, "0/0")
      elseif current_value == math.huge then
        table.insert(result_pack, "math.huge")
      elseif current_value == -math.huge then
        table.insert(result_pack, "-math.huge")
      else
        table.insert(result_pack, tostring(current_value))
      end
    elseif t == "string" then
      table.insert(result_pack, (string.format("%q", current_value):gsub("\\\n","\\n")))
    elseif
      t == "nil" or
      t == "boolean" or
      pretty and (t ~= "table" or (getmetatable(current_value) or {}).__tostring) then
      table.insert(result_pack, tostring(current_value))
    elseif t == "table" then
      if ts[current_value] then
        if pretty then
          table.insert(result_pack, "recursion")
          return
        else
          error("tables with cycles are not supported")
        end
      end
      ts[current_value] = true
      local f
      if pretty then
        local ks, sks, oks = {}, {}, {}
        for k in local_pairs(current_value) do
          if type(k) == "number" then
            table.insert(ks, k)
          elseif type(k) == "string" then
            table.insert(sks, k)
          else
            table.insert(oks, k)
          end
        end
        table.sort(ks)
        table.sort(sks)
        for _, k in ipairs(sks) do
          table.insert(ks, k)
        end
        for _, k in ipairs(oks) do
          table.insert(ks, k)
        end
        local n = 0
        f = table.pack(function()
          n = n + 1
          local k = ks[n]
          if k ~= nil then
            return k, current_value[k]
          else
            return nil
          end
        end)
      else
        f = table.pack(local_pairs(current_value))
      end
      local i = 1
      local first = true
      table.insert(result_pack, "{")
      for k, v in table.unpack(f) do
        if not first then
          table.insert(result_pack, ",")
          if pretty then
            table.insert(result_pack, "\n" .. string.rep(" ", depth))
          end
        end
        first = nil
        local tk = type(k)
        if tk == "number" and k == i then
          i = i + 1
          recurse(v, depth + 1)
        else
          if tk == "string" and not kw[k] and string.match(k, id) then
            table.insert(result_pack, k)
          else
            table.insert(result_pack, "[")
            recurse(k, depth + 1)
            table.insert(result_pack, "]")
          end
          table.insert(result_pack, "=")
          recurse(v, depth + 1)
        end
      end
      ts[current_value] = nil -- allow writing same table more than once
      table.insert(result_pack, "}")
    else
      error("unsupported type: " .. t)
    end
  end
  recurse(value, 1)
  local result = table.concat(result_pack)
  if pretty then
    local limit = type(pretty) == "number" and pretty or 10
    local truncate = 0
    while limit > 0 and truncate do
      truncate = string.find(result, "\n", truncate + 1, true)
      limit = limit - 1
    end
    if truncate then
      return result:sub(1, truncate) .. "..."
    end
  end
  return result
end

function serialization.unserialize(data)
  checkArg(1, data, "string")
  local result, reason = load("return " .. data, "=data", nil, {math={huge=math.huge}})
  if not result then
    return nil, reason
  end
  local ok, output = pcall(result)
  if not ok then
    return nil, output
  end
  return output
end

-------------------------------- text

local text = {}

function text.detab(value, tabWidth)
  checkArg(1, value, "string")
  checkArg(2, tabWidth, "number", "nil")
  tabWidth = tabWidth or 8
  local function rep(match)
    local spaces = tabWidth - match:len() % tabWidth
    return match .. string.rep(" ", spaces)
  end
  local result = value:gsub("([^\n]-)\t", rep) -- truncate results
  return result
end

function text.padLeft(value, length)
  checkArg(1, value, "string", "nil")
  checkArg(2, length, "number")
  if not value or unicode.wlen(value) == 0 then
    return string.rep(" ", length)
  else
    return string.rep(" ", length - unicode.wlen(value)) .. value
  end
end

function text.padRight(value, length)
  checkArg(1, value, "string", "nil")
  checkArg(2, length, "number")
  if not value or unicode.wlen(value) == 0 then
    return string.rep(" ", length)
  else
    return value .. string.rep(" ", length - unicode.wlen(value))
  end
end

-------------------------------- keyboard

-------------------------------- term

local term = {
  cursorX = 1,
  cursorY = 1
}

function term.getGlobalArea()
  local handle = io.popen("stty size 2>/dev/null")
  local output = handle:read("*l")
  handle:close()
  if output then
      local rows, cols = output:match("^(%d+) (%d+)$")
      if rows and cols then
          return 1, 1, tonumber(cols), tonumber(rows)
      end
  end
  return 1, 1, 80, 25
end

function term.setCursor(x, y)
  term.cursorX = x
  term.cursorY = y
  x = x - 1
  y = y - 1
  os.execute("tput cup " .. x .. " " .. y)
end

function term.getCursor()
  return term.cursorX, term.cursorY
end

function term.setCursorBlink(blink)
  if blink then
      io.write("\x1b[?25h") -- show cursor
      -- попробуем включить мигание (некоторые терминалы)
      io.write("\x1b[?12h")
  else
      io.write("\x1b[?25l") -- hide cursor
      -- можно также отключить мигание (но это необязательно)
      io.write("\x1b[?12l")
  end
  io.flush()
end

function term.setEchoEnabled(echo)
  if echo then
    os.execute("stty echo")
  else
    os.execute("stty -echo")
  end
end

function term.clear()
  os.execute("clear")
end

local function rawPull()
  local eventTbl = {}

  return eventTbl
end

function term.pull(eventName)
  local eventTbl = rawPull()
  if eventName then
    if eventTbl[1] == eventName then
      return table.unpack(eventTbl)
    end
  else
    return table.unpack(eventTbl)
  end
end

-------------------------------- filesystem

local fs = {}

local function segments(path)
  local parts = {}
  for part in path:gmatch("[^\\/]+") do
    local current, up = part:find("^%.?%.$")
    if current then
      if up == 2 then
        table.remove(parts)
      end
    else
      table.insert(parts, part)
    end
  end
  return parts
end

local function escPath(path)
  return "\"" .. path .. "\""
end

function fs.canonical(path)
  local result = table.concat(segments(path), "/")
  if unicode.sub(path, 1, 1) == "/" then
    return "/" .. result
  else
    return result
  end
end

function fs.concat(...)
  local set = table.pack(...)
  for index, value in ipairs(set) do
    checkArg(index, value, "string")
  end
  return fs.canonical(table.concat(set, "/"))
end

function fs.absolute(path)
  local cmd = "readlink -f '" .. path .. "' 2>/dev/null"
  local handle = io.popen(cmd)
  local result = handle:read("*l")
  handle:close()
  return result
end

function fs.dirname(path)
  local cmd = "dirname '" .. path .. "' 2>/dev/null"
  local handle = io.popen(cmd)
  local result = handle:read("*l")
  handle:close()
  return result or "."
end

function fs.name(path)
  checkArg(1, path, "string")
  local parts = segments(path)
  return parts[#parts]
end

function fs.exists(path)
  local handle = io.popen("test -e " .. path .. " && echo 0 || echo 1")
  local result = handle:read("*l")
  handle:close()
  return result == "0"
end

function fs.isDirectory(path)
  local handle = io.popen("test -d " .. path .. " && echo 0 || echo 1")
  local result = handle:read("*l")
  handle:close()
  return result == "0"
end

function fs.isReadOnly(path)
  local handle = io.popen("test -w " .. path .. " && echo 0 || echo 1")
  local result = handle:read("*l")
  handle:close()
  return result == "1"
end

function fs.makeDirectory(path)
  os.execute("mkdir " .. escPath(path))
end

-------------------------------- gpu

-- gpu.lua
-- Эмуляция OpenComputers GPU API для Linux-терминала (ANSI escape-последовательности)
-- Совместимость: Lua 5.3+, терминал с поддержкой 24-битного цвета (truecolor)

local gpu = {}

-- ----------------------------------------------------------------------
-- Внутреннее состояние
-- ----------------------------------------------------------------------
local state = {
    width  = 80,      -- текущая ширина (условно)
    height = 25,      -- текущая высота (условно)
    bg     = 0x000000, -- фоновый цвет (RGB)
    fg     = 0xFFFFFF, -- цвет текста (RGB)
    cursor_x = 1,
    cursor_y = 1,
    buffer = {},      -- для эмуляции get(x,y) — хранит символы с цветами
}

-- Буфер для хранения содержимого экрана (для get())
-- Ключи: "x,y" -> {char, fg, bg}
local screen_buffer = {}

-- ----------------------------------------------------------------------
-- Вспомогательные функции
-- ----------------------------------------------------------------------

-- Преобразует 0xRRGGBB в ANSI RGB-строку "r;g;b" (0-255)
local function rgb_to_ansi(rgb)
    local r = math.floor(rgb / 0x10000) % 0x100
    local g = math.floor(rgb / 0x100) % 0x100
    local b = rgb % 0x100
    return string.format("%d;%d;%d", r, g, b)
end

-- Формирует ANSI-последовательность для установки цвета фона (truecolor)
local function ansi_bg(rgb)
    return "\x1b[48;2;" .. rgb_to_ansi(rgb) .. "m"
end

-- Формирует ANSI-последовательность для установки цвета текста (truecolor)
local function ansi_fg(rgb)
    return "\x1b[38;2;" .. rgb_to_ansi(rgb) .. "m"
end

-- Формирует ANSI-последовательность для перемещения курсора (1-based)
local function ansi_goto(x, y)
    return string.format("\x1b[%d;%dH", y, x)
end

-- Формирует ANSI-последовательность для очистки экрана
local function ansi_clear()
    return "\x1b[2J\x1b[H"
end

local function afterGpu()
  term.setCursor(term.getCursor())
end

-- ----------------------------------------------------------------------
-- Публичное API (эмуляция GPU из OpenComputers)
-- ----------------------------------------------------------------------

--- Возвращает текущее разрешение экрана.
function gpu.getResolution()
    return state.width, state.height
end

--- Устанавливает разрешение (эмуляция — просто запоминаем значения).
function gpu.setResolution(w, h)
    state.width = w
    state.height = h
    return true
end

--- Возвращает максимальное поддерживаемое разрешение.
function gpu.maxResolution()
    return 999, 999  -- условно безгранично
end

--- Возвращает текущий цвет фона (RGB).
function gpu.getBackground()
    return state.bg, false  -- false = не палитра
end

--- Устанавливает цвет фона (RGB).
function gpu.setBackground(color)
    state.bg = color
    io.write(ansi_bg(color))
    return color, nil
end

--- Возвращает текущий цвет текста (RGB).
function gpu.getForeground()
    return state.fg, false
end

--- Устанавливает цвет текста (RGB).
function gpu.setForeground(color)
    state.fg = color
    io.write(ansi_fg(color))
    return color, nil
end

--- Записывает строку в указанную позицию (один ряд, без переносов).
function gpu.set(x, y, value)
    -- Обрезаем до ширины экрана (если строка длиннее)
    local str = value
    if #str > state.width - x + 1 then
        str = str:sub(1, state.width - x + 1)
    end

    -- Запоминаем в буфер для get()
    local key = x .. "," .. y
    screen_buffer[key] = { char = str, fg = state.fg, bg = state.bg }

    -- Выводим с сохранением цвета
    io.write(ansi_goto(x, y) .. ansi_fg(state.fg) .. ansi_bg(state.bg) .. str)

    -- Сбрасываем цвет (чтобы не залить весь терминал)
    io.write("\x1b[0m")
    io.flush()

    afterGpu()
    return true
end

--- Возвращает символ в указанной позиции и его цвета.
function gpu.get(x, y)
    local key = x .. "," .. y
    local cell = screen_buffer[key]
    if cell then
        return cell.char, cell.fg, cell.bg, nil, nil
    end
    return nil
end

--- Заполняет прямоугольник указанным символом.
function gpu.fill(x, y, width, height, char)
    if not char or #char == 0 then char = " " end
    local c = char:sub(1, 1)  -- берём первый символ

    for row = y, y + height - 1 do
        for col = x, x + width - 1 do
            if col <= state.width and row <= state.height then
                local key = col .. "," .. row
                screen_buffer[key] = { char = c, fg = state.fg, bg = state.bg }
            end
        end
    end

    -- Для больших заливок используем цикл, но можно оптимизировать через строки
    for row = y, y + height - 1 do
        if row <= state.height then
            local line = string.rep(c, math.min(width, state.width - x + 1))
            io.write(ansi_goto(x, row) .. ansi_fg(state.fg) .. ansi_bg(state.bg) .. line)
        end
    end

    io.write("\x1b[0m")
    io.flush()

    afterGpu()
    return true
end

--- Копирует область буфера в другое место.
function gpu.copy(x, y, width, height, tx, ty)
    local src_x, src_y = x, y
    local dst_x, dst_y = x + tx, y + ty

    -- Собираем данные из буфера (чтобы не зависеть от порядка копирования)
    local cells = {}
    for row = src_y, src_y + height - 1 do
        for col = src_x, src_x + width - 1 do
            local key = col .. "," .. row
            if screen_buffer[key] then
                local dst_key = (col + tx) .. "," .. (row + ty)
                cells[dst_key] = screen_buffer[key]
            end
        end
    end

    -- Применяем скопированные данные
    for dst_key, cell in pairs(cells) do
        screen_buffer[dst_key] = cell
        local c, r = dst_key:match("^(%d+),(%d+)$")
        if c and r then
            c, r = tonumber(c), tonumber(r)
            if c <= state.width and r <= state.height then
                io.write(ansi_goto(c, r) .. ansi_fg(cell.fg) .. ansi_bg(cell.bg) .. cell.char)
            end
        end
    end

    io.write("\x1b[0m")
    io.flush()

    afterGpu()
    return true
end

function gpu.clear()
    io.write(ansi_clear())
    screen_buffer = {}
    io.flush()

    afterGpu()
    return true
end

io.write("\x1b[0m")
gpu.clear()
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)

-------------------------------- edit

local args = {...}

local filename = args[1]
if not filename then
  io.write("Usage: edit <filename>\n")
  os.exit(1)
end

filename = fs.absolute(filename)
local file_parentpath = fs.dirname(filename)

if fs.exists(file_parentpath) and not fs.isDirectory(file_parentpath) then
  io.stderr:write(string.format("Not a directory: %s\n", file_parentpath))
  os.exit(1)
end

local readonly = false
if fs.isDirectory(filename) then
  io.stderr:write("file is a directory\n")
  os.exit(1)
elseif (not fs.exists(filename) and fs.isReadOnly(file_parentpath)) or (fs.exists(filename) and fs.isReadOnly(filename)) then
  readonly = true
  io.stderr:write("file system is read only\n")
  os.exit(1)
end

local function loadConfig()
  -- Try to load user settings.
  local env = {}
  local config = loadfile(config_path, nil, env)
  if config then
    pcall(config)
  end
  -- Fill in defaults.
  env.keybinds = env.keybinds or {
    left = {{"left"}},
    right = {{"right"}},
    up = {{"up"}},
    down = {{"down"}},
    home = {{"home"}},
    eol = {{"end"}},
    pageUp = {{"pageUp"}},
    pageDown = {{"pageDown"}},

    backspace = {{"back"}, {"shift", "back"}},
    delete = {{"delete"}},
    deleteLine = {{"control", "delete"}, {"shift", "delete"}},
    newline = {{"enter"}},

    save = {{"control", "s"}},
    close = {{"control", "w"}},
    find = {{"control", "f"}},
    findnext = {{"control", "g"}, {"control", "n"}, {"f3"}},
    cut = {{"control", "k"}},
    uncut = {{"control", "u"}}
  }
  -- Generate config file if it didn't exist.
  if not config then
    fs.makeDirectory(config_dir_path)
    local f = io.open(config_path, "w")
    if f then
      for k, v in pairs(env) do
          f:write(k.."="..tostring(serialization.serialize(v, math.huge)).."\n")
      end
      f:close()
    end
  end
  return env
end

term.clear()
term.setCursorBlink(true)
term.setEchoEnabled(false)

local running = true
local buffer = {}
local scrollX, scrollY = 0, 0
local config = loadConfig()

local cutBuffer = {}
-- cutting is true while we're in a cutting operation and set to false when cursor changes lines
-- basically, whenever you change lines, the cutting operation ends, so the next time you cut a new buffer will be created
local cutting = false

local getKeyBindHandler -- forward declaration for refind()

local function helpStatusText()
  local function prettifyKeybind(label, command)
    local keybind = type(config.keybinds) == "table" and config.keybinds[command]
    if type(keybind) ~= "table" or type(keybind[1]) ~= "table" then return "" end
    local alt, control, shift, key
    for _, value in ipairs(keybind[1]) do
      if value == "alt" then alt = true
      elseif value == "control" then control = true
      elseif value == "shift" then shift = true
      else key = value end
    end
    if not key then return "" end
    return label .. ": [" ..
           (control and "Ctrl+" or "") ..
           (alt and "Alt+" or "") ..
           (shift and "Shift+" or "") ..
           unicode.upper(key) ..
           "] "
  end
  return prettifyKeybind("Save", "save") ..
         prettifyKeybind("Close", "close") ..
         prettifyKeybind("Find", "find") ..
         prettifyKeybind("Cut", "cut") ..
         prettifyKeybind("Uncut", "uncut")
end

-------------------------------------------------------------------------------

local function setStatus(value)
  local x, y, w, h = term.getGlobalArea()
  value = unicode.wlen(value) > w - 10 and unicode.wtrunc(value, w - 9) or value
  value = text.padRight(value, w - 10)
  gpu.set(x, y + h - 1, value)
end

local function getArea()
  local x, y, w, h = term.getGlobalArea()
  return x, y, w, h - 1
end

local function removePrefix(line, length)
  if length >= unicode.wlen(line) then
    return ""
  else
    local prefix = unicode.wtrunc(line, length + 1)
    local suffix = unicode.sub(line, unicode.len(prefix) + 1)
    length = length - unicode.wlen(prefix)
    if length > 0 then
      suffix = (" "):rep(unicode.charWidth(suffix) - length) .. unicode.sub(suffix, 2)
    end
    return suffix
  end
end

local function lengthToChars(line, length)
  if length > unicode.wlen(line) then
    return unicode.len(line) + 1
  else
    local prefix = unicode.wtrunc(line, length)
    return unicode.len(prefix) + 1
  end
end


local function isWideAtPosition(line, x)
  local index = lengthToChars(line, x)
  if index > unicode.len(line) then
    return false, false
  end
  local prefix = unicode.sub(line, 1, index)
  local char = unicode.sub(line, index, index)
  --isWide, isRight
  return unicode.isWide(char), unicode.wlen(prefix) == x
end

local function drawLine(x, y, w, h, lineNr)
  local yLocal = lineNr - scrollY
  if yLocal > 0 and yLocal <= h then
    local str = removePrefix(buffer[lineNr] or "", scrollX)
    str = unicode.wlen(str) > w and unicode.wtrunc(str, w + 1) or str
    str = text.padRight(str, w)
    gpu.set(x, y - 1 + lineNr - scrollY, str)
  end
end

local function getCursor()
  local cx, cy = term.getCursor()
  return cx + scrollX, cy + scrollY
end

local function line()
  local _, cby = getCursor()
  return buffer[cby] or ""
end

local function getNormalizedCursor()
  local cbx, cby = getCursor()
  local wide, right = isWideAtPosition(buffer[cby], cbx)
  if wide and right then
    cbx = cbx - 1
  end
  return cbx, cby
end

local function setCursor(nbx, nby)
  local x, y, w, h = getArea()
  nbx, nby = math.floor(nbx), math.floor(nby)
  nby = math.max(1, math.min(#buffer, nby))

  local ncy = nby - scrollY
  if ncy > h then
    term.setCursorBlink(false)
    local sy = nby - h
    local dy = math.abs(scrollY - sy)
    scrollY = sy
    if h > dy then
      gpu.copy(x, y + dy, w, h - dy, 0, -dy)
    end
    for lineNr = nby - (math.min(dy, h) - 1), nby do
      drawLine(x, y, w, h, lineNr)
    end
  elseif ncy < 1 then
    term.setCursorBlink(false)
    local sy = nby - 1
    local dy = math.abs(scrollY - sy)
    scrollY = sy
    if h > dy then
      gpu.copy(x, y, w, h - dy, 0, dy)
    end
    for lineNr = nby, nby + (math.min(dy, h) - 1) do
      drawLine(x, y, w, h, lineNr)
    end
  end
  term.setCursor(term.getCursor(), nby - scrollY)

  nbx = math.max(1, math.min(unicode.wlen(line()) + 1, nbx))
  local wide, right = isWideAtPosition(line(), nbx)
  local ncx = nbx - scrollX
  if ncx > w or (ncx + 1 > w and wide and not right) then
    term.setCursorBlink(false)
    scrollX = nbx - w + ((wide and not right) and 1 or 0)
    for lineNr = 1 + scrollY, math.min(h + scrollY, #buffer) do
      drawLine(x, y, w, h, lineNr)
    end
  elseif ncx < 1 or (ncx - 1 < 1 and wide and right) then
    term.setCursorBlink(false)
    scrollX = nbx - 1 - ((wide and right) and 1 or 0)
    for lineNr = 1 + scrollY, math.min(h + scrollY, #buffer) do
      drawLine(x, y, w, h, lineNr)
    end
  end
  term.setCursor(nbx - scrollX, nby - scrollY)
  --update with term lib
  nbx, nby = getCursor()
  local locstring = string.format("%d,%d", nby, nbx)
  if #cutBuffer > 0 then
    locstring = string.format("(#%d) %s", #cutBuffer, locstring)
  end
  locstring = text.padLeft(locstring, 10)
  gpu.set(x + w - #locstring, y + h, locstring)
end

local function highlight(bx, by, length, enabled)
  local x, y, w, h = getArea()
  local cx, cy = bx - scrollX, by - scrollY
  cx = math.max(1, math.min(w, cx))
  cy = math.max(1, math.min(h, cy))
  length = math.max(1, math.min(w - cx, length))

  local fg, fgp = gpu.getForeground()
  local bg, bgp = gpu.getBackground()
  if enabled then
    gpu.setForeground(bg, bgp)
    gpu.setBackground(fg, fgp)
  end
  local indexFrom = lengthToChars(buffer[by], bx)
  local value = unicode.sub(buffer[by], indexFrom)
  if unicode.wlen(value) > length then
    value = unicode.wtrunc(value, length + 1)
  end
  gpu.set(x - 1 + cx, y - 1 + cy, value)
  if enabled then
    gpu.setForeground(fg, fgp)
    gpu.setBackground(bg, bgp)
  end
end

local function home()
  local _, cby = getCursor()
  setCursor(1, cby)
end

local function ende()
  local _, cby = getCursor()
  setCursor(unicode.wlen(line()) + 1, cby)
end

local function left()
  local cbx, cby = getNormalizedCursor()
  if cbx > 1 then
    local wideTarget, rightTarget = isWideAtPosition(line(), cbx - 1)
    if wideTarget and rightTarget then
      setCursor(cbx - 2, cby)
    else
      setCursor(cbx - 1, cby)
    end
    return true -- for backspace
  elseif cby > 1 then
    setCursor(cbx, cby - 1)
    ende()
    return true -- again, for backspace
  end
end

local function right(n)
  n = n or 1
  local cbx, cby = getNormalizedCursor()
  local be = unicode.wlen(line()) + 1
  local wide, isRight = isWideAtPosition(line(), cbx + n)
  if wide and isRight then
    n = n + 1
  end
  if cbx + n <= be then
    setCursor(cbx + n, cby)
  elseif cby < #buffer then
    setCursor(1, cby + 1)
  end
end

local function up(n)
  n = n or 1
  local cbx, cby = getCursor()
  if cby > 1 then
    setCursor(cbx, cby - n)
  end
  cutting = false
end

local function down(n)
  n = n or 1
  local cbx, cby = getCursor()
  if cby < #buffer then
    setCursor(cbx, cby + n)
  end
  cutting = false
end

local function delete(fullRow)
  local _, cy = term.getCursor()
  local cbx, cby = getCursor()
  local x, y, w, h = getArea()
  local function deleteRow(row)
    local content = table.remove(buffer, row)
    local rcy = cy + (row - cby)
    if rcy <= h then
      gpu.copy(x, y + rcy, w, h - rcy, 0, -1)
      drawLine(x, y, w, h, row + (h - rcy))
    end
    return content
  end
  if fullRow then
    term.setCursorBlink(false)
    if #buffer > 1 then
      deleteRow(cby)
    else
      buffer[cby] = ""
      gpu.fill(x, y - 1 + cy, w, 1, " ")
    end
    setCursor(1, cby)
  elseif cbx <= unicode.wlen(line()) then
    term.setCursorBlink(false)
    local index = lengthToChars(line(), cbx)
    buffer[cby] = unicode.sub(line(), 1, index - 1) ..
                  unicode.sub(line(), index + 1)
    drawLine(x, y, w, h, cby)
  elseif cby < #buffer then
    term.setCursorBlink(false)
    local append = deleteRow(cby + 1)
    buffer[cby] = buffer[cby] .. append
    drawLine(x, y, w, h, cby)
  else
    return
  end
  setStatus(helpStatusText())
end

local function insert(value)
  if not value or unicode.len(value) < 1 then
    return
  end
  term.setCursorBlink(false)
  local cbx, cby = getCursor()
  local x, y, w, h = getArea()
  local index = lengthToChars(line(), cbx)
  buffer[cby] = unicode.sub(line(), 1, index - 1) ..
                value ..
                unicode.sub(line(), index)
  drawLine(x, y, w, h, cby)
  right(unicode.wlen(value))
  setStatus(helpStatusText())
end

local function enter()
  term.setCursorBlink(false)
  local _, cy = term.getCursor()
  local cbx, cby = getCursor()
  local x, y, w, h = getArea()
  local index = lengthToChars(line(), cbx)
  table.insert(buffer, cby + 1, unicode.sub(buffer[cby], index))
  buffer[cby] = unicode.sub(buffer[cby], 1, index - 1)
  drawLine(x, y, w, h, cby)
  if cy < h then
    if cy < h - 1 then
      gpu.copy(x, y + cy, w, h - (cy + 1), 0, 1)
    end
    drawLine(x, y, w, h, cby + 1)
  end
  setCursor(1, cby + 1)
  setStatus(helpStatusText())
  cutting = false
end

local findText = ""

local function find()
  local _, _, _, h = getArea()
  local cbx, cby = getCursor()
  local ibx, iby = cbx, cby
  while running do
    if unicode.len(findText) > 0 then
      local sx, sy
      for syo = 1, #buffer do -- iterate lines with wraparound
        sy = (iby + syo - 1 + #buffer - 1) % #buffer + 1
        sx = string.find(buffer[sy], findText, syo == 1 and ibx or 1, true)
        if sx and (sx >= ibx or syo > 1) then
          break
        end
      end
      if not sx then -- special case for single matches
        sy = iby
        sx = string.find(buffer[sy], findText, nil, true)
      end
      if sx then
        sx = unicode.wlen(string.sub(buffer[sy], 1, sx - 1)) + 1
        cbx, cby = sx, sy
        setCursor(cbx, cby)
        highlight(cbx, cby, unicode.wlen(findText), true)
      end
    end
    term.setCursor(7 + unicode.wlen(findText), h + 1)
    setStatus("Find: " .. findText)

    local _, address, char, code = term.pull("key_down")
    local handler, name = getKeyBindHandler(code)
    highlight(cbx, cby, unicode.wlen(findText), false)
    if name == "newline" then
      break
    elseif name == "close" then
      handler()
    elseif name == "backspace" then
      findText = unicode.sub(findText, 1, -2)
    elseif name == "find" or name == "findnext" then
      ibx = cbx + 1
      iby = cby
    elseif not keyboard.isControl(char) then
      findText = findText .. unicode.char(char)
    end
  end
  setCursor(cbx, cby)
  setStatus(helpStatusText())
end

local function cut()
  if not cutting then
    cutBuffer = {}
  end
  local cbx, cby = getCursor()
  table.insert(cutBuffer, buffer[cby])
  delete(true)
  cutting = true
  home()
end

local function uncut()
  home()
  for _, line in ipairs(cutBuffer) do
    insert(line)
    enter()
  end
end

-------------------------------------------------------------------------------

local keyBindHandlers = {
  left = left,
  right = right,
  up = up,
  down = down,
  home = home,
  eol = ende,
  pageUp = function()
    local _, _, _, h = getArea()
    up(h - 1)
  end,
  pageDown = function()
    local _, _, _, h = getArea()
    down(h - 1)
  end,

  backspace = function()
    if not readonly and left() then
      delete()
    end
  end,
  delete = function()
    if not readonly then
      delete()
    end
  end,
  deleteLine = function()
    if not readonly then
      delete(true)
    end
  end,
  newline = function()
    if not readonly then
      enter()
    end
  end,

  save = function()
    if readonly then return end
    local new = not fs.exists(filename)
    local backup
    if not new then
      backup = filename .. "~"
      for i = 1, math.huge do
        if not fs.exists(backup) then
          break
        end
        backup = filename .. "~" .. i
      end
      fs.copy(filename, backup)
    end
    if not fs.exists(file_parentpath) then
      fs.makeDirectory(file_parentpath)
    end
    local f, reason = io.open(filename, "w")
    if f then
      local chars, firstLine = 0, true
      for _, bline in ipairs(buffer) do
        if not firstLine then
          bline = "\n" .. bline
        end
        firstLine = false
        f:write(bline)
        chars = chars + unicode.len(bline)
      end
      f:close()
      local format
      if new then
        format = [["%s" [New] %dL,%dC written]]
      else
        format = [["%s" %dL,%dC written]]
      end
      setStatus(string.format(format, fs.name(filename), #buffer, chars))
    else
      setStatus(reason)
    end
    if not new then
      fs.remove(backup)
    end
  end,
  close = function()
    -- TODO ask to save if changed
    running = false
  end,
  find = function()
    findText = ""
    find()
  end,
  findnext = find,
  cut = cut,
  uncut = uncut
}

getKeyBindHandler = function(code)
  if type(config.keybinds) ~= "table" then return end
  -- Look for matches, prefer more 'precise' keybinds, e.g. prefer
  -- ctrl+del over del.
  local result, resultName, resultWeight = nil, nil, 0
  for command, keybinds in pairs(config.keybinds) do
    if type(keybinds) == "table" and keyBindHandlers[command] then
      for _, keybind in ipairs(keybinds) do
        if type(keybind) == "table" then
          local alt, control, shift, key = false, false, false
          for _, value in ipairs(keybind) do
            if value == "alt" then alt = true
            elseif value == "control" then control = true
            elseif value == "shift" then shift = true
            else key = value end
          end
          if (alt     == not not keyboard.isAltDown()) and
             (control == not not keyboard.isControlDown()) and
             (shift   == not not keyboard.isShiftDown()) and
             code == keyboard.keys[key] and
             #keybind > resultWeight
          then
            resultWeight = #keybind
            resultName = command
            result = keyBindHandlers[command]
          end
        end
      end
    end
  end
  return result, resultName
end

-------------------------------------------------------------------------------

local function onKeyDown(char, code)
  local handler = getKeyBindHandler(code)
  if handler then
    handler()
  elseif readonly and code == keyboard.keys.q then
    running = false
  elseif not readonly then
    if not keyboard.isControl(char) then
      insert(unicode.char(char))
    elseif unicode.char(char) == "\t" then
      insert("  ")
    end
  end
end

local function onClipboard(value)
  value = value:gsub("\r\n", "\n")
  local start = 1
  local l = value:find("\n", 1, true)
  if l then
    repeat
      local next_line = string.sub(value, start, l - 1)
      next_line = text.detab(next_line, 2)
      insert(next_line)
      enter()
      start = l + 1
      l = value:find("\n", start, true)
    until not l
  end
  insert(string.sub(value, start))
end

local function onClick(x, y)
  setCursor(x + scrollX, y + scrollY)
end

local function onScroll(direction)
  local cbx, cby = getCursor()
  setCursor(cbx, cby - direction * 12)
end

-------------------------------------------------------------------------------

do
  local f = io.open(filename)
  if f then
    local x, y, w, h = getArea()
    local chars = 0
    for fline in f:lines() do
      table.insert(buffer, fline)
      chars = chars + unicode.len(fline)
      if #buffer <= h then
        drawLine(x, y, w, h, #buffer)
      end
    end
    f:close()
    if #buffer == 0 then
      table.insert(buffer, "")
    end
    local format
    if readonly then
      format = [["%s" [readonly] %dL,%dC]]
    else
      format = [["%s" %dL,%dC]]
    end
    setStatus(string.format(format, fs.name(filename), #buffer, chars))
  else
    table.insert(buffer, "")
    setStatus(string.format([["%s" [New File] ]], fs.name(filename)))
  end
  setCursor(1, 1)
end

local ok, err = xpcall(function()
  while running do
    local event, address, arg1, arg2, arg3 = term.pull()
    local blink = true
    if event == "key_down" then
      onKeyDown(arg1, arg2)
    elseif event == "clipboard" and not readonly then
      onClipboard(arg1)
    elseif event == "touch" or event == "drag" then
      local x, y, w, h = getArea()
      arg1 = arg1 - x + 1
      arg2 = arg2 - y + 1
      if arg1 >= 1 and arg2 >= 1 and arg1 <= w and arg2 <= h then
        onClick(arg1, arg2)
      end
    elseif event == "scroll" then
      onScroll(arg3)
    else
      blink = false
    end
    if blink then
      term.setCursorBlink(true)
    end
  end
end, debug.traceback)

term.clear()
term.setCursorBlink(true)
term.setEchoEnabled(true)

if not ok then
  io.stderr:write("unhandled exception: " .. tostring(err or "unknown") .. "\n")
end
