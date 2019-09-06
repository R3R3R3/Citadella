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

pm.register_player = function(player_name)
   local timestamp = os.time(os.date("!*t"))
   -- res = assert(
   --    db:execute(
   --       string.format([[
   --        INSERT INTO player
   --        VALUES (%d, %d, %d, %d, '%s', '%s', NULL)]],
   --          pos.x, pos.y, pos.z,
   --          value,
   --          db:escape(item_name),
   --          db:escape(player_name))))
end

pm.get_player = function(player_name)
   return nil
end
