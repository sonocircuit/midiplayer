-- midiplayer v0.1.0 @sonocircuit
-- llllllll.co/t/midiplayer/68868
--
--
--        - play ur midi -
-- 
--
--
-- press K3 to load a midi file.
--
-- press K2 to play back via nb.
-- 
-- add your own midi to:
-- code/midiplayer/midi_files

local fsl = require 'fileselect'
local rfl = require 'reflection'
local mdi = include 'lib/midilua'
local nb = include 'nb/lib/nb'


local g = grid.connect()
local m = midi.connect()


--------- variables ----------

local default_path = _path.code .."midiplayer/midi_files/"

-- UI
local dirtyscreen = false
local shift = false
local is_converting = false
local is_loaded = false
local midi_file_id = ""

-- conversion
local STEP_RES = 96 -- reflection defaults at 96ppqn
local TICK_RES = 0


--------- tables ----------
-- temp storage for pattern data
local p = {}
p.count = 0
p.step = 0
p.event = {}
p.endpoint = 0
p.step_max = 0

--------- pattern playback ----------

pattern = rfl.new(1)
pattern.process = function(e)
  if e.msg == "noteOn" then
    note_on(e.note, e.vel, 1)
  elseif e.msg == "noteOff" then
    note_off(e.note, e.vel, 1)
  end
end
pattern.end_callback = function() is_playing = false dirtyscreen = true end

function note_on(note_num, vel, channel)
  local player = params:lookup_param("nb_player"):get_player()
  local velocity = util.linlin(0, 127, 0, 1, vel)
  player:note_on(note_num, velocity)
end

function note_off(note_num, vel, channel)
  local player = params:lookup_param("nb_player"):get_player()
  player:note_off(note_num)
end


--------- midi conversion ----------

-- format event
function format_event(msg, note, vel)
  local e = {msg = msg, note = note, vel = vel}
  return e
end

-- callback function to grab tick resolution from header
function get_ticks(string, format, tracks, division)
  TICK_RES = division
end

-- handler for note on/off messages
function parse_notes(msg, channel, note, velocity)
  local vel = math.floor(util.linlin(0, 1, 0, 127, velocity))
  local e = format_event(msg, note, vel)
  if not p.event[p.step] then
    p.event[p.step] = {}
  end
  table.insert(p.event[p.step], e)
  p.count = p.count + 1
end

-- handler for deltatime increments
function get_position(ticks)
  local t = math.floor((ticks / TICK_RES) * STEP_RES)
  p.step = p.step + t
  pattern.endpoint = p.step
end

-- callback to for conversion
function to_pattern(msg, ...)
  is_converting = true
  if msg == "noteOn" or msg == "noteOff" then
    parse_notes(msg, ...)
  elseif msg == "deltatime" then
    get_position(...)
  elseif msg == "endOfTrack" then
    p.endpoint = p.step
    is_converting = false
    is_loaded = true
    dirtyscreen = true
    copy_to_pattern()
  end
end

function convert_to_reflection(filename)
  if filename ~= "cancel" and filename ~= "" and filename ~= default_path then
    -- clear temp pattern
    p.count = 0
    p.step = 1
    p.event = {}
    p.endpoint = 0
    -- set file id
    midi_file_id = filename:match("[^/]*$")
    -- read midi and convert
    is_converting = true
    local file = assert(io.open(filename, "rb"))
    mdi.processHeader(file, get_ticks)
    assert(file:seek("set"))
    mdi.processTrack(file, to_pattern, 1)
    file:close()
  end
end

function copy_to_pattern()
  pattern.count = p.count
  pattern.event = deep_copy(p.event)
  pattern.step_max = pattern.endpoint
  print("copied to pattern")
end

function set_midi_file(filename)
  convert_to_reflection(filename, 1)
  screenredrawtimer:start()
  dirtyscreen = true
end


--------- init ----------
function init()

  -- make directory
  if util.file_exists(default_path) == false then
    util.make_dir(default_path)
  end
  
  -- params
  params:add_separator("nb_voice", "nb")
  nb:add_param("nb_player", "nb player")
  nb:add_player_params()

  params:bang()
  
  -- defaults
  pattern:set_loop(0)
    
  -- metros
  screenredrawtimer = metro.init(function() screen_redraw() end, 1/15, -1)
  screenredrawtimer:start()
  dirtyscreen = true

end


--------- norns UI ----------
function key(n, z)
  if n == 1 then
    shift = z == 1 and true or false -- // use K1 as shift key
  end
  if n == 2 and z == 1 then
    if is_loaded then
      if pattern.play == 1 then
        pattern:stop()
        is_playing = false
      else
        pattern:start()
        is_playing = true
      end
    end
  elseif n == 3 and z == 1 then
    screenredrawtimer:stop()
    fsl.enter(default_path, function(filename) set_midi_file(filename) end)
  end
  dirtyscreen = true
end

function redraw()
  screen.clear()
  screen.font_face(68)

  if is_converting then
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 37)
    screen.text_center("loading midi file...")
  elseif is_loaded then
    local action_text = is_playing and "file playing: " or "file loaded: "
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 31)
    screen.text_center(action_text)
    screen.move(64, 43)
    screen.text_center(midi_file_id)
  else
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 37)
    screen.text_center("load midi file: K3")
  end
  
  screen.update()
end


--------- redraw  ----------
function screen_redraw()
  if dirtyscreen then
    redraw()
    dirtyscreen = false
  end
end

function hardware_redraw()
  if dirtygrid then
    gridredraw()
    dirtygrid = false
  end
end


--------- utilities ----------

function deep_copy(tbl)
  local ret = {}
  if type(tbl) ~= 'table' then return tbl end
  for key, value in pairs(tbl) do
    ret[key] = deep_copy(value)
  end
  return ret
end

function print_event_tab()
  for k, v in pairs(p.event) do
    print("events @ step "..k)
    for e, v in pairs(p.event[k]) do
      print("event "..e)
      tab.print(p.event[k][e])
    end
  end
end


--------- cleanup ----------
function cleanup()
  print("all nice and tidy here")
end
