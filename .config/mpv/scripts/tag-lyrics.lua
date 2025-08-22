-- MPV Tag Lyrics Script
-- Reads lyrics from audio file tags, handles synchronized LRC format
-- Falls back to toggle display for unsynchronized lyrics

local mp = require 'mp'
local msg = require 'mp.msg'

-- Script state
local lyrics_data = {}
local current_lyrics = ""
local is_synchronized = false
local show_static = false
local lyrics_overlay = nil

-- Configuration
local config = {
  font_size = 20,
  font_color = "FFFFFF",
  border_color = "000000",
  border_size = 1,
  position_y = 95,         -- Bottom of screen (percentage)
  fade_duration = 0.3,
  static_toggle_key = "o", -- Key to toggle static lyrics
}

-- Parse LRC format timestamps [mm:ss.xx] or [mm:ss]
local function parse_time(time_str)
  local min, sec, ms = time_str:match("(%d+):(%d+)%.(%d+)")
  if min and sec and ms then
    return tonumber(min) * 60 + tonumber(sec) + tonumber(ms) / 100
  end

  local min2, sec2 = time_str:match("(%d+):(%d+)")
  if min2 and sec2 then
    return tonumber(min2) * 60 + tonumber(sec2)
  end

  return nil
end

-- Parse LRC format lyrics
local function parse_lrc(text)
  local lines = {}
  local has_timestamps = false

  for line in text:gmatch("[^\r\n]+") do
    -- Match LRC format: [mm:ss.xx]text or [mm:ss]text
    local time_part, lyric_text = line:match("^%[([%d:%.]+)%](.*)$")

    if time_part and lyric_text then
      local time_seconds = parse_time(time_part)
      if time_seconds then
        table.insert(lines, {
          time = time_seconds,
          text = lyric_text:gsub("^%s*", ""):gsub("%s*$", "") -- trim whitespace
        })
        has_timestamps = true
      end
    end
  end

  -- Sort by timestamp
  if has_timestamps then
    table.sort(lines, function(a, b) return a.time < b.time end)
  end

  return lines, has_timestamps
end

-- Get current lyric line for synchronized lyrics
local function get_current_lyric(current_time)
  if not is_synchronized or #lyrics_data == 0 then
    return ""
  end

  local current_line = ""
  for i, line in ipairs(lyrics_data) do
    if current_time >= line.time then
      current_line = line.text
    else
      break
    end
  end

  return current_line
end

-- Create lyrics overlay
local function create_overlay(text)
  if lyrics_overlay then
    lyrics_overlay:remove()
  end

  if text == "" then
    return
  end

  local ass_text = string.format(
    "{\\an2\\pos(640,720)\\fs%d\\c&H%s&\\3c&H%s&\\bord%d}%s",
    config.font_size,
    config.font_color,
    config.border_color,
    config.border_size,
    text:gsub("\n", "\\N")
  )

  lyrics_overlay = mp.create_osd_overlay("ass-events")
  lyrics_overlay.data = ass_text
  lyrics_overlay:update()
end

-- Update lyrics display
local function update_lyrics_display()
  if is_synchronized then
    mp.osd_message("Sync lyrics found")
    local current_time = mp.get_property_number("time-pos")
    if current_time then
      local current_lyric = get_current_lyric(current_time)
      if current_lyric ~= current_lyrics then
        current_lyrics = current_lyric
        create_overlay(current_lyric)
      end
    end
  elseif show_static then
    mp.osd_message("Static lyrics found")
    local static_text = table.concat(lyrics_data, "\n")
    create_overlay(static_text)
  else
    mp.osd_message("No lyrics found")
    if lyrics_overlay then
      lyrics_overlay:remove()
      lyrics_overlay = nil
    end
  end
end

-- Toggle static lyrics display
local function toggle_static_lyrics()
  if not is_synchronized and #lyrics_data > 0 then
    show_static = not show_static
    update_lyrics_display()

    if show_static then
      mp.osd_message("Lyrics: ON", 2)
    else
      mp.osd_message("Lyrics: OFF", 2)
    end
  end
end

-- Load lyrics from file metadata
local function load_lyrics()
  lyrics_data = {}
  current_lyrics = ""
  is_synchronized = false
  show_static = false

  if lyrics_overlay then
    lyrics_overlay:remove()
    lyrics_overlay = nil
  end

  -- Try different metadata keys for lyrics
  local metadata = mp.get_property_native("metadata") or {}
  local lyrics_text = metadata["LYRICS"] or
      metadata["lyrics"] or
      metadata["UNSYNCEDLYRICS"] or
      metadata["unsyncedlyrics"] or
      metadata["SYNCEDLYRICS"] or
      metadata["syncedlyrics"]

  if not lyrics_text or lyrics_text == "" then
    msg.verbose("No lyrics found in metadata")
    return
  end

  msg.info("Found lyrics in metadata")

  -- Try to parse as LRC format
  local parsed_lines, has_sync = parse_lrc(lyrics_text)

  if has_sync and #parsed_lines > 0 then
    lyrics_data = parsed_lines
    is_synchronized = true
    msg.info("Loaded synchronized lyrics (" .. #lyrics_data .. " lines)")
  else
    -- Store as plain text lines for static display
    for line in lyrics_text:gmatch("[^\r\n]+") do
      local trimmed = line:gsub("^%s*", ""):gsub("%s*$", "")
      if trimmed ~= "" then
        table.insert(lyrics_data, trimmed)
      end
    end
    is_synchronized = false
    msg.info("Loaded unsynchronized lyrics (" .. #lyrics_data .. " lines)")
  end
end

-- Event handlers
mp.register_event("file-loaded", load_lyrics)

-- Update synchronized lyrics periodically
local function lyrics_timer()
  if is_synchronized then
    update_lyrics_display()
  end
end

-- Set up timer for synchronized lyrics (update every 100ms)
mp.add_periodic_timer(0.1, lyrics_timer)

-- Key binding for toggling static lyrics
mp.add_key_binding(config.static_toggle_key, "toggle-lyrics", update_lyrics_display)

msg.info("Tag Lyrics script loaded - Press '" .. config.static_toggle_key .. "' to toggle static lyrics")
