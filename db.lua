--[[

Database connection functionality via PostgreSQL.

`luarocks install luasql-postgres`

]]--

--[[

  prepare(db, query, ...)

A PreparedStatement-like query execution helper for luasql-postgres.
Automatically quotes and escapes strings passed as arguments. Parameters are
denoted with the question-mark character ('?').

Reports count mismatches in SQL query parameters and function args and provides
pretty good debugging context.

Acceptable arguments are of types: string, nil, number.

Example usage:
   prepare(db, "INSERT INTO tab VALUES (?, ?)", "Fred", 22)

Doesn't support ? characters embedded in strings in query. Use:
   prepare(db, "INSERT INTO tab2 VALUES (?)", "lol?")

--]]
function prepare(db, query, ...)
   local join_table = {}
   local argc = select('#', ...)

   local escaped
   local val
   local valtype

   local fin = false
   local i = 0
   for split_query in string.gmatch(query, "[^%?]+") do
      if fin then
         error("prepare(): Too few function arguments (context: \""
                  .. table.concat(join_table) .. "\")", 3)
      end

      i = i + 1
      table.insert(join_table, split_query)

      if i > argc then
         fin = true
      else
         val = select(i, ...)
         valtype = type(val)

         if valtype == "string" then
            escaped = "'" .. db:escape(val) .. "'"
         elseif valtype == "number" then
            escaped = db:escape(tostring(val))
         elseif valtype == "nil" then
            escaped = "NULL"
         else
            error("prepare(): Arg " .. tostring(i)
                     .. " is not of type: string, number, nil (context: \""
                     .. table.concat(join_table) .. "\")")
         end

         table.insert(join_table, escaped)
      end
   end
   if i ~= (argc + 1) then
      error("prepare(): Arg count doesn't equal SQL parameter count (context: \""
               .. table.concat(join_table) .. "\")")
   end
   return db:execute(table.concat(join_table))
end

local ie = minetest.request_insecure_environment() or
   error("Mod requires decreased security settings in minetest.conf")

local driver = ie.require("luasql.postgres")
local db = nil
local env = nil

local function prep_db()
   env = assert (driver.postgres())
   -- connect to data source
   db = assert (env:connect("citadella", "mt"))

   -- create reinforcements table
   res = assert(prepare(db, [[
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
