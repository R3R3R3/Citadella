## Citadella

A [minetest](https://github.com/CivClassic/Citadel) clone of the server-side
[Citadel mod](https://github.com/CivClassic/Citadel) for Minecraft.

Licensed under the terms of the [LGPL 2.1](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html).

**Note: highly work-in-progress.**

### Features

Not yet.

### Installation

Clone the Citadella repository into the `mods` folder of your minetest server
(or client).

Ensure that mod security is disabled via `minetest.conf` (for dedicated
servers):

```
secure.enable_security = false
```

Or via `Main Menu > Settings > All Settings > Enable mod security` (for
singleplayer).

Install [luarocks](https://luarocks.org/), configure it for a Lua 5.1
environment, and install the
[luasql-postgres](https://luarocks.org/modules/tomasguisasola/luasql-postgres)
package.

Then, run your minetest server (or singleplayer world), and enjoy.
