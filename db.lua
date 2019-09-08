--[[

Database connection functionality via PostgreSQL.

`luarocks install luasql-postgres`

]]--

local ie = minetest.request_insecure_environment() or
   error("Mod requires decreased security settings in minetest.conf")

local driver = ie.require("luasql.postgres")
local db = nil
local env = nil

local u = pmutils

local function prep_db()
   env = assert (driver.postgres())
   -- connect to data source
   db = assert (env:connect("citadella", "mt"))

   -- create reinforcements table
   res = assert(u.prepare(db, [[
     CREATE TABLE IF NOT EXISTS reinforcement (
         x INTEGER NOT NULL,
         y INTEGER NOT NULL,
         z INTEGER NOT NULL,
         value INTEGER NOT NULL,
         material VARCHAR(50) NOT NULL,
         ctgroup_id VARCHAR(32) REFERENCES ctgroup(id),
         PRIMARY KEY (x, y, z)
     )]]))
end


prep_db()


minetest.register_on_shutdown(function()
   db:close()
   env:close()
end)

return db
