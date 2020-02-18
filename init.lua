-- global callbacks
trail = {}

local default_modpath = minetest.get_modpath("default")

local S = minetest.get_translator(minetest.get_current_modname())

-- Parameters

local GLOBALSTEP_INTERVAL = 0.2 -- Function cycle in seconds.

local HARDPACK_PROBABILITY = minetest.settings:get("trail_hardpack_probability") or 0.9 -- Chance walked dirt/grass is worn and compacted to trail:trail.
local HARDPACK_COUNT = minetest.settings:get("trail_hardpack_count") or 5 -- Number of times the above chance needs to be passed for soil to compact.
local EROSION = minetest.settings:get_bool("trail_erosion", true) -- Enable footprint erosion.
local TRAIL_EROSION = minetest.settings:get_bool("trail_trail_erosion", false) -- Allow hard-packed soil to erode back to dirt
local EROSION_INTERVAL = minetest.settings:get("trail_erosion_interval") or 16 -- Erosion interval.
local EROSION_CHANCE = minetest.settings:get("trail_erosion_chance") or 128 -- Erosion 1/x chance.

-- Utility

local function deep_copy(input)
	if type(input) ~= "table" then
		return input
	end
	local output = {}
	for index, value in pairs(input) do
		output[index] = deep_copy(value)
	end
	return output
end

-- Player positions

local player_pos_previous_map = {}

minetest.register_on_joinplayer(function(player)
	player_pos_previous_map[player:get_player_name()] = {x = 0, y = 0, z = 0}
end)

minetest.register_on_leaveplayer(function(player)
	player_pos_previous_map[player:get_player_name()] = nil
end)

local trails = {}
local erosion = {}

trail.register_trample_node = function(trampleable_node_name, trample_def)
	trample_def = trample_def or {} -- Everything has defaults, so if no trample_def is passed in just use an empty table.

	if trails[trampleable_node_name] then
		minetest.log("error", "[trail] Attempted to call trail.register_trample_node to register trampleable node "
			.. trampleable_node_name ..", which has already been registered as trampleable.")
		return			
	end
	local trampleable_node_def = minetest.registered_nodes[trampleable_node_name]
	if trampleable_node_def == nil then
		minetest.log("error", "[trail] Attempted to call trail.register_trample_node with the trampleable node "
			.. trampleable_node_name ..", which has not yet been registered as a node.")
		return
	end
	
	local trampled_node_name = trample_def.trampled_node_name or trampleable_node_name.."_trampled"
	if not minetest.registered_nodes[trampled_node_name] then
		local trampled_node_def = deep_copy(trampleable_node_def) -- start with a deep copy of the source node's definition
		if trample_def.trampled_node_def_override then -- override any values that need to be overridden explicitly
			for key, value in pairs(trample_def.trampled_node_def_override) do
				trampled_node_def[key] = value
			end
		end
		
		-- Set up the erosion ABM group
		if EROSION and trample_def.erodes ~= false then
			local groups = trampled_node_def.groups or {}
			groups.trail_erodes = 1
			trampled_node_def.groups = groups
			erosion[trampled_node_name] = trampleable_node_name
		end
		
		-- If the source node doesn't have a special drop, then set drop to drop a source node rather than dropping a node with a footstep.
		if trampled_node_def.drop == nil then
			trampled_node_def.drop = trampleable_node_name
		end
		
		-- Modify the +Y tile with a footprint overlay
		if trample_def.add_footprint_overlay ~= false then
			local footprint_overlay = trample_def.footprint_overlay or "trail_footprint.png"
			local footprint_opacity = trample_def.footprint_opacity or 64
			local overlay_texture = "^(" .. footprint_overlay .. "^[opacity:" .. tostring(footprint_opacity) .. ")"

			local tiles = trampled_node_def.tiles
			local first_tile = tiles[1]
			local second_tile = tiles[2]
			if second_tile == nil then
				-- The provided node def only has one tile for all sides. We need to only modify the +Y tile,
				-- so we need to copy the original first tile into the second tile slot
				tiles[2] = deep_copy(first_tile)
			end
			if type(first_tile) == "table" then
				first_tile.name = first_tile.name .. overlay_texture
			elseif type(first_tile) == "string" then
				first_tile = first_tile .. overlay_texture
			end
			trampled_node_def.tiles[1] = first_tile
		end

		minetest.register_node(":"..trampled_node_name, trampled_node_def)
		
		-- If hard pack has been defined for this trail type, add it
		local hard_pack_node_name = trample_def.hard_pack_node_name
		if hard_pack_node_name then
			local hard_pack_probability = trample_def.hard_pack_probability or 0.1
			local hard_pack_count = trample_def.hard_pack_count or 1
			trails[trampled_node_name] = {name=hard_pack_node_name, probability=hard_pack_probability, count = hard_pack_count}
		end
	end	

	local probability = trample_def.probability or 1
	local trample_count = trample_def.trample_count or 1
	trails[trampleable_node_name] = {name=trampled_node_name, probability=probability, randomize_trampled_param2 = trample_def.randomize_trampled_param2, count = trample_count}
end

trail.register_erosion = function(source_node_name, destination_node_name)
	if not EROSION then
		return
	end
	
	if minetest.registered_nodes[source_node_name] == nil then
		minetest.log("error", "[trail] attempted to call trail.register_erosion with unregistered source node "
			.. source_node_name)
		return
	end
	if minetest.registered_nodes[destination_node_name] == nil then
		minetest.log("error", "[trail] attempted to call trail.register_erosion with unregistered destination node "
			.. destination_node_name)
		return	
	end
	if minetest.get_item_group(source_node_name, "trail_erodes") == 0 then
		minetest.log("error", "[trail] attempted to call trail.register_erosion with source node "
			.. destination_node_name .. " that wasn't in group trail_erodes.")
		return
	end
	
	erosion[source_node_name] = destination_node_name
end

-- Nodes

if default_modpath then
	-- hard-packed soil
	local trail_trail_def = {
		tiles = {"trail_trailtop.png", "default_dirt.png",
			"default_dirt.png^trail_trailside.png"},
		groups = {crumbly = 2},
		drop = "default:dirt",
		sounds = default.node_sound_dirt_defaults(),
	}
	if TRAIL_EROSION then
		trail_trail_def.groups.trail_erodes = 1
	end
	minetest.register_node("trail:trail", trail_trail_def)
	if TRAIL_EROSION then
		trail.register_erosion("trail:trail", "default:dirt")
	end

	-- hard-packed dry soil
	local trail_dry_trail_def = {
		tiles = {"trail_trailtop.png", "default_dry_dirt.png",
			"default_dry_dirt.png^trail_trailside.png"},
		groups = {crumbly = 2},
		drop = "default:dry_dirt",
		sounds = default.node_sound_dirt_defaults(),
	}
	if TRAIL_EROSION then
		trail_dry_trail_def.groups.trail_erodes = 1
	end
	minetest.register_node("trail:dry_trail", trail_dry_trail_def)
	if TRAIL_EROSION then
		trail.register_erosion("trail:dry_trail", "default:dry_dirt")
	end

	-- Default dirt

	trail.register_trample_node("default:dirt", {
		trampled_node_name = "trail:dirt",
		trampled_node_def_override = {description = S("Dirt with Footprint"),},
		hard_pack_node_name = "trail:trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	trail.register_trample_node("default:dirt_with_grass", {
		trampled_node_name = "trail:dirt_with_grass",
		trampled_node_def_override = {description = S("Dirt with Grass and Footprint"),},
		hard_pack_node_name = "trail:trail",
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	trail.register_trample_node("default:dirt_with_dry_grass", {
		trampled_node_name = "trail:dirt_with_dry_grass",
		trampled_node_def_override = {description = S("Dirt with Dry Grass and Footprint"),},
		hard_pack_node_name = "trail:trail",
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	trail.register_trample_node("default:dirt_with_snow", {
		trampled_node_name = "trail:dirt_with_snow",
		trampled_node_def_override = {description = S("Dirt with Snow and Footprint"),},
		hard_pack_node_name = "trail:trail",
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	trail.register_trample_node("default:dirt_with_rainforest_litter", {
		trampled_node_name = "trail:dirt_with_rainforest_litter",
		trampled_node_def_override = {description = S("Dirt with Rainforest Litter and Footprint"),},
		hard_pack_node_name = "trail:trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	trail.register_trample_node("default:dirt_with_coniferous_litter", {
		trampled_node_name = "trail:dirt_with_coniferous_litter",
		trampled_node_def_override = {description = S("Dirt with Coniferous Litter and Footprint"),},
		hard_pack_node_name = "trail:trail",
		footprint_opacity = 128,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	trail.register_trample_node("default:dry_dirt", {
		trampled_node_name = "trail:dry_dirt",
		trampled_node_def_override = {description = S("Dry Dirt with Footprint"),},
		hard_pack_node_name = "trail:dry_trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	trail.register_trample_node("default:dry_dirt_with_dry_grass", {
		trampled_node_name = "trail:dry_dirt_with_dry_grass",
		trampled_node_def_override = {description = S("Dry Dirt with Dry Grass and Footprint"),},
		hard_pack_node_name = "trail:dry_trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	-- Default sand

	trail.register_trample_node("default:sand", {
		trampled_node_name = "trail:sand",
		trampled_node_def_override = {description = S("Sand with Footprint"),},
	})

	trail.register_trample_node("default:desert_sand", {
		trampled_node_name = "trail:desert_sand",
		trampled_node_def_override = {description = S("Desert Sand with Footprint"),},
	})

	trail.register_trample_node("default:silver_sand", {
		trampled_node_name = "trail:silver_sand",
		trampled_node_def_override = {description = S("Silver Sand with Footprint"),},
	})

	trail.register_trample_node("default:gravel", {
		trampled_node_name = "trail:gravel",
		trampled_node_def_override = {description = S("Gravel with Footprint"),},
		footprint_opacity = 128,
	})

	-- Default snow

	trail.register_trample_node("default:snowblock", {
		trampled_node_name = "trail:snowblock",
		trampled_node_def_override = {description = S("Snow Block with Footprint"),},
		hard_pack_node_name = "default:ice",
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	trail.register_trample_node("default:snow", {
		trampled_node_name = "trail:snow",
		trampled_node_def_override = {description = S("Snow with Footprint"),},
	})
end

if minetest.get_modpath("farming") then
	local hoe_converts_nodes = {}

	local sounds
	if default_modpath then
		sounds = default.node_sound_leaves_defaults()
	end
	-- Flattened wheat
	minetest.register_node("trail:wheat", {
		description = S("Flattened Wheat"),
		tiles = {"trail_flat_wheat.png"},
		inventory_image = "trail_flat_wheat.png",
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "facedir",
		buildable_to = true,
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, -3 / 8, 0.5}
			},
		},
		groups = {snappy = 3, flammable = 2, attached_node = 1},
		drop = "",
		sounds = sounds,
	})
	
	trail.register_trample_node("farming:wheat_5", {
		trampled_node_name = "trail:wheat",
		randomize_trampled_param2 = true,
	})
	trail.register_trample_node("farming:wheat_6", {
		trampled_node_name = "trail:wheat",
		randomize_trampled_param2 = true,
	})
	trail.register_trample_node("farming:wheat_7", {
		trampled_node_name = "trail:wheat",
		randomize_trampled_param2 = true,
	})
	trail.register_trample_node("farming:wheat_8", {
		trampled_node_name = "trail:wheat",
		randomize_trampled_param2 = true,
	})
	
	minetest.register_node("trail:cotton", {
		description = S("Flattened Cotton"),
		tiles = {"trail_flat_cotton.png"},
		inventory_image = "trail_flat_cotton.png",
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "facedir",
		buildable_to = true,
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, -3 / 8, 0.5}
			},
		},
		groups = {snappy = 3, flammable = 2, attached_node = 1},
		drop = "",
		sounds = sounds,
	})
	
	trail.register_trample_node("farming:cotton_5", {
		trampled_node_name = "trail:cotton",
		randomize_trampled_param2 = true,
	})
	trail.register_trample_node("farming:cotton_6", {
		trampled_node_name = "trail:cotton",
		randomize_trampled_param2 = true,
	})
	trail.register_trample_node("farming:cotton_7", {
		trampled_node_name = "trail:cotton",
		randomize_trampled_param2 = true,
	})
	trail.register_trample_node("farming:cotton_8", {
		trampled_node_name = "trail:cotton",
		randomize_trampled_param2 = true,
	})
	
	-- Allow hoes to turn hardpack back into bare dirt
	trail.register_hoe_converts = function(target_node, converted_node)
		hoe_converts_nodes[target_node] = converted_node
	end
	
	local old_hoe_on_use = farming.hoe_on_use
	if not old_hoe_on_use then
		-- Something's wrong, don't override
		return
	end

	local new_hoe_on_use = function(itemstack, user, pointed_thing, uses)
		local pt = pointed_thing
		-- check if pointing at a node
		if not pt then
			return
		end
		if pt.type ~= "node" then
			return
		end
	
		local under_node = minetest.get_node(pt.under)
		local restore_node = hoe_converts_nodes[under_node.name]

		-- check if pointing at hardpack
		if restore_node then
			if minetest.is_protected(pt.under, user:get_player_name()) then
				minetest.record_protection_violation(pt.under, user:get_player_name())
				return
			end
	
			-- turn the node into soil and play sound
			minetest.set_node(pt.under, {name = restore_node})
			minetest.sound_play("default_dig_crumbly", {
				pos = pt.under,
				gain = 0.5,
			})
			if not (creative and creative.is_enabled_for 
					and creative.is_enabled_for(user:get_player_name())) then
				-- wear tool
				local wdef = itemstack:get_definition()
				itemstack:add_wear(65535/(uses-1))
				-- tool break sound
				if itemstack:get_count() == 0 and wdef.sound and wdef.sound.breaks then
					minetest.sound_play(wdef.sound.breaks, {pos = pt.above, gain = 0.5})
				end
			end
			return itemstack
		end
		
		return old_hoe_on_use(itemstack, user, pointed_thing, uses)
	end
	
	farming.hoe_on_use = new_hoe_on_use
else
	trail.register_hoe_converts = function(target_node, converted_node)
	end
end

if default_modpath then
	trail.register_hoe_converts("trail:trail", "default:dirt")
	trail.register_hoe_converts("trail:dry_trail", "default:dry_dirt")
end

-- Globalstep function

local timer = 0

local get_param2 = function(trail_def)
	if trail_def.randomize_trampled_param2 then
		return math.random(0,3)
	end
	return 0
end

local test_trample_count = function(trail_def, pos)
	local target_count = trail_def.count
	if target_count <= 1 then
		return true
	end
	local meta = minetest.get_meta(pos)
	local trampled_count = meta:get_int("trail_trample_count")
	trampled_count = trampled_count + 1
	if trampled_count >= target_count then
		return true
	end
	meta:set_int("trail_trample_count", trampled_count)
	return false
end

local math_floor = math.floor

minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer > GLOBALSTEP_INTERVAL then
		timer = 0
		for _, player in ipairs(minetest.get_connected_players()) do
			local pos = player:get_pos()
			local player_name = player:get_player_name()
			local pos_x_plus_half = math_floor(pos.x + 0.5)
			local pos_z_plus_half = math_floor(pos.z + 0.5)
			local pos_y = pos.y
			local current_player_pos = {
				x = pos_x_plus_half,
				y = math_floor(pos_y + 0.2),
				z = pos_z_plus_half
			}
			
			--if player_pos_previous_map[player_name] == nil then
				--break
			--end
			
			local player_pos_previous = player_pos_previous_map[player_name]

			if current_player_pos.x ~= player_pos_previous.x or
				current_player_pos.y < player_pos_previous.y or
				current_player_pos.z ~= player_pos_previous.z then
				
				local pos_ground_cover = {
					x = pos_x_plus_half,
					y = math_floor(pos_y + 1.2),
					z = pos_z_plus_half
				}
				local name_ground_cover = minetest.get_node(pos_ground_cover).name
				
				-- test ground cover first (snow, wheat)
				local trail_def = trails[name_ground_cover]
				if trail_def then
					if math.random() <= trail_def.probability then
						local pos_ground_cover_plus = {
							x = pos_x_plus_half,
							y = math_floor(pos_y + 0.5),
							z = pos_z_plus_half
						}
						if test_trample_count(trail_def, pos_ground_cover_plus) then
							minetest.set_node(pos_ground_cover_plus, {name = trail_def.name, param2 = get_param2(trail_def)})
						end
					end
				else
					local pos_ground = {
						x = pos_x_plus_half,
						y = math_floor(pos_y + 0.4),
						z = pos_z_plus_half
					}
					local name_ground = minetest.get_node(pos_ground).name
					trail_def = trails[name_ground]
					if trail_def and math.random() <= trail_def.probability then
						local pos_groundpl = {
							x = pos_x_plus_half,
							y = math_floor(pos_y - 0.5),
							z =pos_z_plus_half
						}
						if test_trample_count(trail_def, pos_groundpl) then
							minetest.set_node(pos_groundpl, {name = trail_def.name, param2 = get_param2(trail_def)})
						end
					end
				end
			end

			player_pos_previous_map[player_name] = current_player_pos
		end
	end
end)


-- ABM

if EROSION then
	minetest.register_abm({
		nodenames = {"group:trail_erodes"},
		interval = EROSION_INTERVAL,
		chance = EROSION_CHANCE,
		catch_up = true,
		action = function(pos, node, _, _)
			local nodename = node.name
			local erodes_to = erosion[nodename]
			if erodes_to then
				local meta = minetest.get_meta(pos)
				local trampled_count = meta:get_int("trail_trample_count") - 1
				if trampled_count <= 0 then
					minetest.set_node(pos, {name = erodes_to})
				else
					meta:set_int("trail_trample_count", trampled_count)
				end				
			else
				minetest.log("error", "[trail] The node " .. nodename .. " is in group trail_erodes but "
					.. " didn't have an erosion target node defined.")
			end
		end
	})
end
