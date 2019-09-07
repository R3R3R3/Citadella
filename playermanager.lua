--[[

Player management in Citadella (and beyond!)

Handles new player registry and player groups.

]]--

local pm = {}

--[[
Random id generator, adapted from
https://gist.github.com/haggen/2fd643ea9a261fea2094#gistcomment-2339900

Generate random hex strings as player uuids
]]--
local charset = {}  do -- [0-9a-f]
    for c = 48, 57  do table.insert(charset, string.char(c)) end
    for c = 97, 102 do table.insert(charset, string.char(c)) end
end

local function random_string(length)
    if not length or length <= 0 then return '' end
    math.randomseed(os.clock()^5)
    return random_string(length - 1) .. charset[math.random(1, #charset)]
end

--[[ player management proper ]]--

local function generate_id()
   return random_string(16)
end

local QUERY_REGISTER_PLAYER = [[
  INSERT INTO player (id, name, join_date)
  VALUES (?, ?, CURRENT_TIMESTAMP)
  ON CONFLICT DO NOTHING
]]

function pm.register_player(player_name)
   local player_id = generate_id()
   return assert(prepare(db, QUERY_REGISTER_PLAYER, player_id, player_name))
end

local QUERY_GET_PLAYER_BY_NAME = [[
  SELECT * FROM player WHERE player.name = ?
]]

function pm.get_player_by_name(player_name)
   local cur = prepare(db, QUERY_GET_PLAYER_BY_NAME, player_name)
   if cur then
      return cur:fetch({}, "a")
   else
      return nil
   end
end

local QUERY_GET_PLAYER_BY_ID = [[
  SELECT * FROM player WHERE player.id = ?
]]

function pm.get_player_by_id(player_id)
   local cur = prepare(db, QUERY_GET_PLAYER_BY_ID, player_id)
   if cur then
      return cur:fetch({}, "a")
   else
      return nil
   end
end

-- pm.register_player("Garfunel")

--[[ GROUPS ]]--

local QUERY_REGISTER_GROUP = [[
  INSERT INTO ctgroup (id, name, creation_date)
  VALUES (?, ?, CURRENT_TIMESTAMP)
  ON CONFLICT DO NOTHING
]]

function pm.register_group(ctgroup_name)
   local ctgroup_id = generate_id()
   return assert(prepare(db, QUERY_REGISTER_GROUP, ctgroup_id, ctgroup_name))
end

local QUERY_GET_GROUP_BY_NAME = [[
  SELECT * FROM ctgroup WHERE ctgroup.name = ?
]]

function pm.get_group_by_name(ctgroup_name)
   local cur = prepare(db, QUERY_GET_GROUP_BY_NAME, ctgroup_name)
   if cur then
      return cur:fetch({}, "a")
   else
      return nil
   end
end

local QUERY_GET_GROUP_BY_ID = [[
  SELECT * FROM ctgroup WHERE ctgroup.id = ?
]]

function pm.get_group_by_id(ctgroup_id)
   local cur = prepare(db, QUERY_GET_GROUP_BY_ID, ctgroup_id)
   if cur then
      return cur:fetch({}, "a")
   else
      return nil
   end
end

--[[ PLAYER <--> GROUPS ]]--

local QUERY_REGISTER_PLAYER_GROUP_PERMISSION = [[
  INSERT INTO player_ctgroup (player_id, ctgroup_id, permission)
  VALUES (?, ?, ?)
  ON CONFLICT DO NOTHING
]]

function pm.register_player_group_permission(player_id, ctgroup_id, permission)
   return assert(prepare(db, QUERY_REGISTER_PLAYER_GROUP_PERMISSION,
                         player_id, ctgroup_id, permission))
end

local QUERY_GET_PLAYER_GROUP_PERMISSION = [[
  SELECT * FROM player_ctgroup
  WHERE player_ctgroup.player_id = ?
    AND player_ctgroup.ctgroup_id = ?
]]

function pm.get_player_group(player_id, ctgroup_id)
   local cur = prepare(db, QUERY_GET_PLAYER_GROUP_PERMISSION,
                       player_id, ctgroup_id)
   if cur then
      return cur:fetch({}, "a")
   else
      return nil
   end
end

local QUERY_UPDATE_PLAYER_GROUP_PERMISSION = [[
  UPDATE player_ctgroup SET permission = ?
  WHERE player_ctgroup.player_id = ?
    AND player_ctgroup.ctgroup_id = ?
]]

function pm.update_player_group(player_id, ctgroup_id, permission)
   return assert(prepare(db, QUERY_UPDATE_PLAYER_GROUP_PERMISSION,
                         permission, player_id, ctgroup_id))
end

--[[ End of DB interface ]]--

local function pm_parse_params(pname, params)
   local accum = {}
   for chunk in string.gmatch(params, "[^%s]+") do
      table.insert(accum, chunk)
   end

   if #accum < 2 then
      return false, "Malformed command."
   end

   local action = accum[1]
   local group_name = accum[2]

   local player_id = pm.get_player_by_name(pname).id

   if action == "create" then
      if string.len(group_name) > 16 then
         return false, "Group name '"..group_name..
            "' is too long (16 character limit)."
      end
      pm.register_group(group_name)
      local ctgroup_id = pm.get_group_by_name(group_name).id
      pm.register_player_group_permission(player_id, ctgroup_id, "admin")
      return true, "Group '"..group_name.."' created successfully."
   end

   local ctgroup = pm.get_group_by_name(group_name)
   if not ctgroup then
      return false, "Group '"..group_name.."' not found."
   end
   local ctgroup_id = ctgroup.id

   local player_group_info = pm.get_player_group(player_id, ctgroup_id)
   if not player_group_info then
      return false, "You are not on group '"..group_name.."'."
   end
   local permission = player_group_info.permission

   if action == "info" then
      return true,
      "[Group: "..group_name.."]\n" ..
         "Your permission level: "..permission.."\n" ..
         "\n" ..
         "Admins: "..tostring(nil).."\n" ..
         "Mods: "..tostring(nil).."\n" ..
         "Members: "..tostring(nil).."\n"
   elseif action == "add" then
      if permission ~= "admin" then
         return false, "You don't have permission to do that."
      end

      local target = accum[3]
      local target_player = pm.get_player_by_name(target)
      if not target_player then
         return false, "Player '"..target.."' not found."
      end

      local target_player_group_info
         = pm.get_player_group(target_player.id, ctgroup_id)
      if target_player_group_info then
         return false, "Player '"..target_player.name ..
            "' is already in group '"..group_name.."'."
      end

      pm.register_player_group_permission(target_player.id, ctgroup_id, "member")
      return true, "Player '"..target_player.name.."' added to group '" ..
         group_name.."'."
   elseif action == "rank" then
      if permission ~= "admin" then
         return false, "You don't have permission to do that."
      end
      local target = accum[3]
      local target_rank = accum[4]
      local target_player = pm.get_player_by_name(target)
      if not target_player then
         return false, "Player '"..target.."' not found."
      end
      local target_player_group_info
         = pm.get_player_group(target_player.id, ctgroup_id)
      if not target_player_group_info then
         return false, "Player '"..target_player.name ..
            "' is not in group '"..group_name.."'."
      end
      if target_rank ~= "member" and
         target_rank ~= "mod" and
         target_rank ~= "admin"
      then
         return false, "Invalid permission '"..target_rank ..
            "', must be one of: member, mod, admin."
      end

      pm.update_player_group(target_player.id, ctgroup_id, target_rank)
      return true, "Promoted player '"..target_player.name.."' to '" ..
         target_rank.."' of group '"..group_name.."'."
   end

   return false, "Unknown action: '"..action.."'."
end


minetest.register_chatcommand("group", {
   params = "<action> <group name> [<params...>]",
   description = "PlayerManager group management.",
   func = function(pname, params)
      local player = minetest.get_player_by_name(pname)
      if not player then
         return false
      end
      local success, message = pm_parse_params(pname, params)
      minetest.chat_send_player(pname, message)
      return success
   end
})


minetest.register_on_joinplayer(function(player)
      local pname = player:get_player_name(player)
      if not pm.get_player_by_name(pname) then
         pm.register_player(pname)
         minetest.after(
            3,
            function(pname)
               minetest.chat_send_player(pname,
                  "You wake up in an unfamiliar place..."
               )
            end,
            pname)
      end
end)

return pm
