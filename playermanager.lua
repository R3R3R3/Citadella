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
   return random_string(32)
end

local QUERY_REGISTER_PLAYER = [[
  INSERT INTO player (id, name, join_date)
  VALUES (?, ?, CURRENT_TIMESTAMP)
]]

function pm.register_player(player_name)
   local player_id = generate_id()
   res = assert(prepare(db, QUERY_REGISTER_PLAYER, player_id, player_name))
end

local QUERY_GET_PLAYER_BY_NAME = [[
  SELECT * FROM player WHERE player.name = ?
]]

function pm.get_player_by_name(player_name)
   cur = assert(prepare(db, QUERY_GET_PLAYER_BY_NAME, player_name))
   return cur:fetch({}, "a")
end

local QUERY_GET_PLAYER_BY_ID = [[
  SELECT * FROM player WHERE player.id = ?
]]

function pm.get_player_by_id(player_id)
   cur = assert(prepare(db, QUERY_GET_PLAYER_BY_ID, player_id))
   return cur:fetch({}, "a")
end

-- pm.register_player("Garfunel")

--[[ GROUPS ]]--

function pm.register_group(group_name, player)
   return nil
end

function pm.get_group_by_name(group_name)
   return nil
end

function pm.get_group_by_id(group_id)
   return nil
end

return pm
