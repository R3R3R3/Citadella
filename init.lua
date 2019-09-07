--[[

init.lua

Entrypoint to this plugin.

--]]

ct = {}

minetest.debug("Citadella initialised")

local modpath = minetest.get_modpath(minetest.get_current_modname())

local db = dofile(modpath .. "/db.lua")
assert(loadfile(modpath .. "/citadella.lua"))(db)

return ct
