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
]]

function pm.register_player(player_name)
   local player_id = generate_id()
   assert(prepare(db, QUERY_REGISTER_PLAYER, player_id, player_name))
end

local QUERY_GET_PLAYER_BY_NAME = [[
  SELECT * FROM player WHERE player.name = ?
]]

function pm.get_player_by_name(player_name)
   local cur = assert(prepare(db, QUERY_GET_PLAYER_BY_NAME, player_name))
   return cur:fetch({}, "a")
end

local QUERY_GET_PLAYER_BY_ID = [[
  SELECT * FROM player WHERE player.id = ?
]]

function pm.get_player_by_id(player_id)
   local cur = assert(prepare(db, QUERY_GET_PLAYER_BY_ID, player_id))
   return cur:fetch({}, "a")
end

-- pm.register_player("Garfunel")

--[[ GROUPS ]]--

local QUERY_REGISTER_GROUP = [[
  INSERT INTO ctgroup (id, name, creation_date)
  VALUES (?, ?, CURRENT_TIMESTAMP)
]]

function pm.register_group(ctgroup_name)
   local ctgroup_id = generate_id()
   assert(prepare(db, QUERY_REGISTER_GROUP, ctgroup_id, ctgroup_name))
end

local QUERY_GET_GROUP_BY_NAME = [[
  SELECT * FROM ctgroup WHERE ctgroup.name = ?
]]

function pm.get_group_by_name(ctgroup_name)
   local cur = assert(prepare(db, QUERY_GET_GROUP_BY_NAME, ctgroup_name))
   return cur:fetch({}, "a")
end

local QUERY_GET_GROUP_BY_ID = [[
  SELECT * FROM ctgroup WHERE ctgroup.id = ?
]]

function pm.get_group_by_id(ctgroup_id)
   local cur = assert(prepare(db, QUERY_GET_GROUP_BY_ID, ctgroup_id))
   return cur:fetch({}, "a")
end

--[[ PLAYER <--> GROUPS ]]--

local QUERY_REGISTER_PLAYER_GROUP_PERMISSION = [[
  INSERT INTO player_ctgroup (player_id, ctgroup_id, permission)
  VALUES (?, ?, ?)
]]

function pm.register_player_group_permission(player_id, ctgroup_id, permission)
   assert(prepare(db, QUERY_REGISTER_PLAYER_GROUP_PERMISSION,
                  player_id, ctgroup_id, permission))
end

local QUERY_GET_PLAYER_GROUP_PERMISSION = [[
  SELECT * FROM player_ctgroup
  WHERE player_ctgroup.player_id = ?
    AND player_ctgroup.ctgroup_id = ?
]]

function pm.get_player_group_permission(player_id, ctgroup_id)
   local cur = assert(prepare(db, QUERY_GET_PLAYER_GROUP_PERMISSION,
                              player_id, ctgroup_id))
   return (cur:fetch({}, "a")).permission
end

minetest.register_chatcommand("mkgrp", {
   params = "<grpname>",
   description = "Make a PlayerManager group",
   func = function(name, param)
      local player = minetest.get_player_by_name(name)
      if not player then
         return false
      end
      local pname = player:get_player_name()
      minetest.chat_send_player(pname, param)

      pm.register_player(pname)
      local player_id = pm.get_player_by_name(pname).id
      pm.register_group(param)
      local ctgroup_id = pm.get_group_by_name(param).id
      pm.register_player_group_permission(player_id, ctgroup_id, "admin")
      return true
   end
})


return pm
