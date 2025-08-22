local utils = require 'mp.utils'
local os = require 'os'

-- current timestamp in ISO 8601 format
local function iso8601_now()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function move_to_trash()
  local path = mp.get_property("path")
  if not path then return end

  local fullpath    = utils.join_path(mp.get_property_native("working-directory"), path)
  local trash_files = os.getenv("HOME") .. "/.local/share/Trash/files/"
  local trash_info  = os.getenv("HOME") .. "/.local/share/Trash/info/"
  local res = utils.subprocess({ args = { "mkdir", "-p", trash_files, trash_info } })
  if res.status ~= 0 then
    mp.osd_message("Failed to ensure trash paths")
    return
  end

  local filename = path:match("^.+/(.+)$") or path
  local target = trash_files .. filename
  res = utils.subprocess({ args = { "mv", fullpath, target } })
  if res.status ~= 0 then
    mp.osd_message("Failed to move file to Trash")
    return
  end

  -- .trashinfo data, although not same as thunar's timestamp
  local info_path = trash_info .. filename .. ".trashinfo"
  local f = io.open(info_path, "w")
  if f then
    f:write("[Trash Info]\n")
    f:write("Path=" .. fullpath .. "\n")
    f:write("DeletionDate=" .. iso8601_now() .. "\n")
    f:close()
  end

  mp.osd_message("Moved to Trash: " .. filename)
  mp.command("playlist-next")
end

mp.add_key_binding("DEL", "trash-delete", move_to_trash)
