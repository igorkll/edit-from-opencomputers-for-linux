#!/usr/bin/lua5.3

-- edit-from-opencomputers-for-linux: https://github.com/igorkll/edit-from-opencomputers-for-linux

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

function unicode.char(...)
  local ok, res = pcall(utf8.char, ...)
  if ok then
    return res
  else
    return nil, res
  end
end

function unicode.len(s)
  local ok, res = pcall(utf8.len, s)
  if ok then
    return res
  else
    return nil, res
  end
end

function unicode.upper(s)
  return string.upper(s)
end

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
    n = n - 1
    if n < 0 then
        return ""
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

local keyboard = {pressedChars = {}, pressedCodes = {}}

keyboard.keys = {
  c               = 0x2E,
  d               = 0x20,
  q               = 0x10,
  w               = 0x11,
  back            = 0x0E, -- backspace
  delete          = 0xD3,
  down            = 0xD0,
  enter           = 0x1C,
  home            = 0xC7,
  lcontrol        = 0x1D,
  left            = 0xCB,
  lmenu           = 0x38, -- left Alt
  lshift          = 0x2A,
  pageDown        = 0xD1,
  rcontrol        = 0x9D,
  right           = 0xCD,
  rmenu           = 0xB8, -- right Alt
  rshift          = 0x36,
  space           = 0x39,
  tab             = 0x0F,
  up              = 0xC8,
  ["end"]         = 0xCF,
  numpadenter     = 0x9C,
}

keyboard.keys["1"]           = 0x02
keyboard.keys["2"]           = 0x03
keyboard.keys["3"]           = 0x04
keyboard.keys["4"]           = 0x05
keyboard.keys["5"]           = 0x06
keyboard.keys["6"]           = 0x07
keyboard.keys["7"]           = 0x08
keyboard.keys["8"]           = 0x09
keyboard.keys["9"]           = 0x0A
keyboard.keys["0"]           = 0x0B
keyboard.keys.a               = 0x1E
keyboard.keys.b               = 0x30
keyboard.keys.c               = 0x2E
keyboard.keys.d               = 0x20
keyboard.keys.e               = 0x12
keyboard.keys.f               = 0x21
keyboard.keys.g               = 0x22
keyboard.keys.h               = 0x23
keyboard.keys.i               = 0x17
keyboard.keys.j               = 0x24
keyboard.keys.k               = 0x25
keyboard.keys.l               = 0x26
keyboard.keys.m               = 0x32
keyboard.keys.n               = 0x31
keyboard.keys.o               = 0x18
keyboard.keys.p               = 0x19
keyboard.keys.q               = 0x10
keyboard.keys.r               = 0x13
keyboard.keys.s               = 0x1F
keyboard.keys.t               = 0x14
keyboard.keys.u               = 0x16
keyboard.keys.v               = 0x2F
keyboard.keys.w               = 0x11
keyboard.keys.x               = 0x2D
keyboard.keys.y               = 0x15
keyboard.keys.z               = 0x2C

keyboard.keys.apostrophe      = 0x28
keyboard.keys.at              = 0x91
keyboard.keys.back            = 0x0E -- backspace
keyboard.keys.backslash       = 0x2B
keyboard.keys.capital         = 0x3A -- capslock
keyboard.keys.colon           = 0x92
keyboard.keys.comma           = 0x33
keyboard.keys.enter           = 0x1C
keyboard.keys.equals          = 0x0D
keyboard.keys.grave           = 0x29 -- accent grave
keyboard.keys.lbracket        = 0x1A
keyboard.keys.lcontrol        = 0x1D
keyboard.keys.lmenu           = 0x38 -- left Alt
keyboard.keys.lshift          = 0x2A
keyboard.keys.minus           = 0x0C
keyboard.keys.numlock         = 0x45
keyboard.keys.pause           = 0xC5
keyboard.keys.period          = 0x34
keyboard.keys.rbracket        = 0x1B
keyboard.keys.rcontrol        = 0x9D
keyboard.keys.rmenu           = 0xB8 -- right Alt
keyboard.keys.rshift          = 0x36
keyboard.keys.scroll          = 0x46 -- Scroll Lock
keyboard.keys.semicolon       = 0x27
keyboard.keys.slash           = 0x35 -- / on main keyboard
keyboard.keys.space           = 0x39
keyboard.keys.stop            = 0x95
keyboard.keys.tab             = 0x0F
keyboard.keys.underline       = 0x93

-- Keypad (and numpad with numlock off)
keyboard.keys.up              = 0xC8
keyboard.keys.down            = 0xD0
keyboard.keys.left            = 0xCB
keyboard.keys.right           = 0xCD
keyboard.keys.home            = 0xC7
keyboard.keys["end"]         = 0xCF
keyboard.keys.pageUp          = 0xC9
keyboard.keys.pageDown        = 0xD1
keyboard.keys.insert          = 0xD2
keyboard.keys.delete          = 0xD3

-- Function keys
keyboard.keys.f1              = 0x3B
keyboard.keys.f2              = 0x3C
keyboard.keys.f3              = 0x3D
keyboard.keys.f4              = 0x3E
keyboard.keys.f5              = 0x3F
keyboard.keys.f6              = 0x40
keyboard.keys.f7              = 0x41
keyboard.keys.f8              = 0x42
keyboard.keys.f9              = 0x43
keyboard.keys.f10             = 0x44
keyboard.keys.f11             = 0x57
keyboard.keys.f12             = 0x58
keyboard.keys.f13             = 0x64
keyboard.keys.f14             = 0x65
keyboard.keys.f15             = 0x66
keyboard.keys.f16             = 0x67
keyboard.keys.f17             = 0x68
keyboard.keys.f18             = 0x69
keyboard.keys.f19             = 0x71

-- Japanese keyboards
keyboard.keys.kana            = 0x70
keyboard.keys.kanji           = 0x94
keyboard.keys.convert         = 0x79
keyboard.keys.noconvert       = 0x7B
keyboard.keys.yen             = 0x7D
keyboard.keys.circumflex      = 0x90
keyboard.keys.ax              = 0x96

-- Numpad
keyboard.keys.numpad0         = 0x52
keyboard.keys.numpad1         = 0x4F
keyboard.keys.numpad2         = 0x50
keyboard.keys.numpad3         = 0x51
keyboard.keys.numpad4         = 0x4B
keyboard.keys.numpad5         = 0x4C
keyboard.keys.numpad6         = 0x4D
keyboard.keys.numpad7         = 0x47
keyboard.keys.numpad8         = 0x48
keyboard.keys.numpad9         = 0x49
keyboard.keys.numpadmul       = 0x37
keyboard.keys.numpaddiv       = 0xB5
keyboard.keys.numpadsub       = 0x4A
keyboard.keys.numpadadd       = 0x4E
keyboard.keys.numpaddecimal   = 0x53
keyboard.keys.numpadcomma     = 0xB3
keyboard.keys.numpadenter     = 0x9C
keyboard.keys.numpadequals    = 0x8D

-- Create inverse mapping for name lookup.
setmetatable(keyboard.keys,
{
  __index = function(tbl, k)
    if type(k) ~= "number" then return end
    for name,value in pairs(tbl) do
      if value == k then
        return name
      end
    end
  end
})

function keyboard.isAltDown()
  return keyboard.pressedCodes[keyboard.keys.lmenu] or keyboard.pressedCodes[keyboard.keys.rmenu]
end

function keyboard.isControl(char)
  return type(char) == "number" and (char < 0x20 or (char >= 0x7F and char <= 0x9F))
end

function keyboard.isControlDown()
  return keyboard.pressedCodes[keyboard.keys.lcontrol] or keyboard.pressedCodes[keyboard.keys.rcontrol]
end

function keyboard.isShiftDown()
  return keyboard.pressedCodes[keyboard.keys.lshift] or keyboard.pressedCodes[keyboard.keys.rshift]
end

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

local function ansi_goto(x, y)
  return string.format("\x1b[%d;%dH", y, x)
end

function term.setCursor(x, y)
  term.cursorX = x
  term.cursorY = y
  io.write(ansi_goto(x, y))
end

function term.getCursor()
  return term.cursorX, term.cursorY
end

local cursorBlinking = false
function term.setCursorBlink(blink)
  cursorBlinking = blink
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

local function read_byte()
  return io.stdin:read(1)
end

local function read_utf8_char()
  local first = read_byte()
  if not first then return nil end
  local byte = string.byte(first)
  local len
  if byte < 0x80 then
      len = 1
  elseif byte < 0xE0 then
      len = 2
  elseif byte < 0xF0 then
      len = 3
  elseif byte < 0xF8 then
      len = 4
  else
      return first -- невалидный UTF-8
  end
  local chars = {first}
  for i = 2, len do
      local b = read_byte()
      if not b then break end
      table.insert(chars, b)
  end
  return table.concat(chars)
end

local function rawKeyboardPull()
  local char = read_utf8_char()
  if not char then
    return
  end

  local charbyte = string.byte(char)

  if charbyte == 27 then
    local seq = char
    local next_byte = read_byte()
    if next_byte then
        seq = seq .. next_byte
        while true do
            local b = read_byte()
            if not b then break end
            seq = seq .. b
            local last = b:byte()
            if (last >= 0x40 and last <= 0x7E) or last == 0x7E then
                break
            end
        end
    end
    if seq:byte(2) == 91 then
      if seq:byte(3) == 65 then
        return {"key_down", "keyboard", 0, keyboard.keys.up}
      elseif seq:byte(3) == 66 then
        return {"key_down", "keyboard", 0, keyboard.keys.down}
      elseif seq:byte(3) == 67 then
        return {"key_down", "keyboard", 0, keyboard.keys.right}
      elseif seq:byte(3) == 68 then
        return {"key_down", "keyboard", 0, keyboard.keys.left}
      elseif seq:byte(3) == 51 then
        return {"key_down", "keyboard", 0, keyboard.keys.delete}
      elseif seq:byte(3) == 70 then
        return {"key_down", "keyboard", 0, keyboard.keys["end"]}
      elseif seq:byte(3) == 53 then
        return {"key_down", "keyboard", 0, keyboard.keys.pageUp}
      elseif seq:byte(3) == 54 then
        return {"key_down", "keyboard", 0, keyboard.keys.pageDown}
      elseif seq:byte(3) == 72 then
        return {"key_down", "keyboard", 0, keyboard.keys.home}
      elseif seq:byte(3) == 50 then
        return {"key_down", "keyboard", 0, keyboard.keys.insert}
      else
        --os.execute("reset")
        --print(seq:byte(3))
        --os.exit(1)
      end
    end
  end

  if charbyte == 10 then
    return {"key_down", "keyboard", 13, 28}
  elseif charbyte == 127 then
    return {"key_down", "keyboard", 8, 14}
  end

  return {"key_down", "keyboard", charbyte, 0}
end

function term.pull(eventName)
  local eventTbl = rawKeyboardPull() or {}

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

local gpu = {}

local state = {
  width  = 80,
  height = 25,
  bg     = 0x000000,
  fg     = 0xFFFFFF,
  buffer = {},
  buffer2 = {}
}

function gpu.getResolution()
  return state.width, state.height
end

function gpu.setResolution(w, h)
  state.width = w
  state.height = h
  return true
end

function gpu.getBackground()
  return state.bg, false
end

function gpu.setBackground(color)
  state.bg = color
  return color, nil
end

function gpu.getForeground()
  return state.fg, false
end

function gpu.setForeground(color)
  state.fg = color
  return color, nil
end

function gpu.set(x, y, value)
  x = x - 1
  y = y - 1
  for i = 1, unicode.len(value) do
    state.buffer[x + (y * state.width)] = {state.bg, state.fg, unicode.sub(value, i, i)}
    x = x + 1
    if x > state.width then return end
  end
end

function gpu.fill(x, y, width, height, char)
  local x2 = x + (width - 1)
  local y2 = y + (height - 1)
  for ix = x, x2 do
    for iy = y, y2 do
      gpu.set(ix, iy, char)
    end
  end
end

function gpu.copy(x, y, width, height, tx, ty)
  local w = state.width
  local h = state.height
  local temp = {}  -- временное хранилище для копируемых ячеек

  for i = 0, width - 1 do
      for j = 0, height - 1 do
          local sx = x + i
          local sy = y + j
          local dx = sx + tx
          local dy = sy + ty

          -- Читаем только если исходная точка в пределах буфера
          if sx >= 1 and sx <= w and sy >= 1 and sy <= h then
              local src_idx = (sx - 1) + ((sy - 1) * w)
              local cell = state.buffer[src_idx]
              if cell then
                  -- Записываем во временный буфер, если целевая точка в пределах
                  if dx >= 1 and dx <= w and dy >= 1 and dy <= h then
                      local dst_idx = (dx - 1) + ((dy - 1) * w)
                      temp[dst_idx] = cell
                  end
              end
          end
      end
  end

  for idx, cell in pairs(temp) do
      state.buffer[idx] = cell
  end
end

local function rgb_to_ansi(rgb)
  local r = math.floor(rgb / 0x10000) % 0x100
  local g = math.floor(rgb / 0x100) % 0x100
  local b = rgb % 0x100
  return string.format("%d;%d;%d", r, g, b)
end

local function ansi_bg(rgb)
  return "\x1b[48;2;" .. rgb_to_ansi(rgb) .. "m"
end

local function ansi_fg(rgb)
  return "\x1b[38;2;" .. rgb_to_ansi(rgb) .. "m"
end

local function ansi_clear()
  return "\x1b[2J\x1b[H"
end

local function bufcmp(v1, v2)
  if not v2 then return true end
  return v1[1] ~= v2[1] or v1[2] ~= v2[2] or v1[3] ~= v2[3]
end

function gpu.update()
  local changed = false
  for iy = 1, state.height do
    for ix = 1, state.width do
      local bufidx = (ix - 1) + ((iy - 1) * state.width)
      if bufcmp(state.buffer[bufidx], state.buffer2[bufidx]) then
        changed = true
        break
      end
    end
    if changed then break end
  end
  if not changed then return end

  term.setCursorBlink(false)
  for iy = 1, state.height do
    for ix = 1, state.width do
      local bufidx = (ix - 1) + ((iy - 1) * state.width)
      if bufcmp(state.buffer[bufidx], state.buffer2[bufidx]) then
        local charinfo = state.buffer[bufidx]

        io.write(ansi_goto(ix, iy))
        io.write(ansi_bg(charinfo[1]))
        io.write(ansi_fg(charinfo[2]))
        io.write(charinfo[3])

        state.buffer2[bufidx] = state.buffer[bufidx]
      end
    end
  end
  term.setCursor(term.getCursor())
  term.setCursorBlink(true)
end

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

os.execute("clear")
--os.execute("stty -echo -icanon min 1 time 0")
os.execute("stty -echo -icanon -ixon min 1 time 0")
term.setCursorBlink(true)
term.setEchoEnabled(false)

local _, _, rx, ry = term.getGlobalArea()
gpu.setResolution(rx, ry)
gpu.fill(1, 1, rx, ry, " ")
gpu.update()

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

    gpu.update()
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
    gpu.update()
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

os.execute("reset")

if not ok then
  io.stderr:write("unhandled exception: " .. tostring(err or "unknown") .. "\n")
end
