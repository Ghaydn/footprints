-- global callbacks
trail = {}

-- Parameters

local FOO = true -- Enable footprints.
local FUNCYC = 0.2 -- Function cycle in seconds.

local TRACHA = minetest.settings:get("trail_hardpack_chance") or 0.1 -- Chance walked dirt/grass is worn and compacted to trail:trail.
local ICECHA = minetest.settings:get("trail_ice_chance") or 0.05 -- Chance walked snowblock is compacted to ice.
local EROSION = minetest.settings:get_bool("trail_erosion", true) -- Enable footprint erosion.
local TRAIL_EROSION = minetest.settings:get_bool("trail_trail_erosion", true) -- Allow hard-packed soil to erode back to dirt
local EROINT = minetest.settings:get("trail_erosion_interval") or 16 -- Erosion interval.
local EROCHA = minetest.settings:get("trail_erosion_chance") or 128 -- Erosion 1/x chance.


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

local player_pos_previous = {}

minetest.register_on_joinplayer(function(player)
	player_pos_previous[player:get_player_name()] = {x = 0, y = 0, z = 0}
end)

minetest.register_on_leaveplayer(function(player)
	player_pos_previous[player:get_player_name()] = nil
end)

local trails = {}
local erosion = {}

trail.register_trample_node = function(trampleable_node_name, trample_def)
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
			local tiles = trampled_node_def.tiles
			local first_tile = tiles[1]
			local second_tile = tiles[2]
			if second_tile == nil then
				-- The provided node def only has one tile for all sides. We need to only modify the +Y tile,
				-- so we need to copy the original first tile into the second tile slot
				tiles[2] = deep_copy(first_tile)
			end		
			if type(first_tile) == "table" then
				first_tile.name = first_tile.name .. "^default_footprint.png"
			elseif type(first_tile) == "string" then
				first_tile = first_tile .. "^default_footprint.png"
			end
			trampled_node_def.tiles[1] = first_tile
		end

		minetest.register_node(":"..trampled_node_name, trampled_node_def)
		
		-- If hard pack has been defined for this trail type, add it
		local hard_pack_node_name = trample_def.hard_pack_node_name
		if hard_pack_node_name then
			local hard_pack_probability = trample_def.hard_pack_probability or 0.1
			trails[trampled_node_name] = {name=hard_pack_node_name, probability=hard_pack_probability}
		end
	end	

	local probability = trample_def.probability or 1
	trails[trampleable_node_name] = {name=trampled_node_name, probability=probability, randomize_trampled_param2 = trample_def.randomize_trampled_param2,}
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

-- Default dirt

trail.register_trample_node("default:dirt", {
	trampled_node_name = "trail:dirt",
	trampled_node_def_override = {description = "Dirt with Footprint",},
	hard_pack_node_name = "trail:trail",
	hard_pack_probability = TRACHA,
})

trail.register_trample_node("default:dirt_with_grass", {
	trampled_node_name = "trail:dirt_with_grass",
	trampled_node_def_override = {description = "Dirt with Grass and Footprint",},
	hard_pack_node_name = "trail:trail",
	hard_pack_probability = TRACHA,
})

trail.register_trample_node("default:dirt_with_dry_grass", {
	trampled_node_name = "trail:dirt_with_dry_grass",
	trampled_node_def_override = {description = "Dirt with Dry Grass and Footprint",},
	hard_pack_node_name = "trail:trail",
	hard_pack_probability = TRACHA,
})

trail.register_trample_node("default:dirt_with_snow", {
	trampled_node_name = "trail:dirt_with_snow",
	trampled_node_def_override = {description = "Dirt with Snow and Footprint",},
	hard_pack_node_name = "trail:trail",
	hard_pack_probability = TRACHA,
})

trail.register_trample_node("default:dirt_with_rainforest_litter", {
	trampled_node_name = "trail:dirt_with_rainforest_litter",
	trampled_node_def_override = {description = "Dirt with Rainforest Litter and Footprint",},
	hard_pack_node_name = "trail:trail",
	hard_pack_probability = TRACHA,
})

trail.register_trample_node("default:dirt_with_coniferous_litter", {
	trampled_node_name = "trail:dirt_with_coniferous_litter",
	trampled_node_def_override = {description = "Dirt with Coniferous Litter and Footprint",},
	hard_pack_node_name = "trail:trail",
	hard_pack_probability = TRACHA,
})

-- Default sand

trail.register_trample_node("default:sand", {
	trampled_node_name = "trail:sand",
	trampled_node_def_override = {description = "Sand with Footprint",},
})

trail.register_trample_node("default:desert_sand", {
	trampled_node_name = "trail:desert_sand",
	trampled_node_def_override = {description = "Desert Sand with Footprint",},
})

trail.register_trample_node("default:silver_sand", {
	trampled_node_name = "trail:silver_sand",
	trampled_node_def_override = {description = "Silver Sand with Footprint",},
})

trail.register_trample_node("default:gravel", {
	trampled_node_name = "trail:gravel",
	trampled_node_def_override = {description = "Gravel with Footprint",},
})

-- Default snow

trail.register_trample_node("default:snowblock", {
	trampled_node_name = "trail:snowblock",
	trampled_node_def_override = {description = "Snow Block with Footprint",},
	hard_pack_node_name = "default:ice",
	hard_pack_probability = ICECHA,
})

trail.register_trample_node("default:snow", {
	trampled_node_name = "trail:snow",
	trampled_node_def_override = {description = "Snow with Footprint",},
})


if minetest.get_modpath("farming") then
	-- Flattened wheat
	minetest.register_node("trail:wheat", {
		description = "Flattened Wheat",
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
		sounds = default.node_sound_leaves_defaults(),
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
end

-- Globalstep function

if FOO then
	local timer = 0
	
	local get_param2 = function(trail_def)
		if trail_def.randomize_trampled_param2 then
			return math.random(0,3)
		end
		return 0
	end
	
	minetest.register_globalstep(function(dtime)
		timer = timer + dtime
		if timer > FUNCYC then
			timer = 0
			for _, player in ipairs(minetest.get_connected_players()) do
				local pos = player:getpos()
				local player_name = player:get_player_name()
				local current_player_pos = {
					x = math.floor(pos.x + 0.5),
					y = math.floor(pos.y + 0.2),
					z = math.floor(pos.z + 0.5)
				}
				
				--if player_pos_previous[player_name] == nil then
					--break
				--end

				if current_player_pos.x ~= player_pos_previous[player_name].x or
					current_player_pos.y < player_pos_previous[player_name].y or
					current_player_pos.z ~= player_pos_previous[player_name].z then
					
					local p_snow = {
						x = math.floor(pos.x + 0.5),
						y = math.floor(pos.y + 1.2),
						z = math.floor(pos.z + 0.5)
					}
					local n_snow = minetest.get_node(p_snow).name
					
					-- test ground cover first (snow, wheat)
					local trail_def = trails[n_snow]
					if trail_def then
						if math.random() <= trail_def.probability then
							local p_snowpl = {
								x = math.floor(pos.x + 0.5),
								y = math.floor(pos.y + 0.5),
								z = math.floor(pos.z + 0.5)
							}
							minetest.set_node(p_snowpl, {name = trail_def.name, param2 = get_param2(trail_def)})
						end
					else
						local p_ground = {
							x = math.floor(pos.x + 0.5),
							y = math.floor(pos.y + 0.4),
							z = math.floor(pos.z + 0.5)
						}
						local n_ground = minetest.get_node(p_ground).name
						trail_def = trails[n_ground]
						if trail_def and math.random() <= trail_def.probability then
							local p_groundpl = {
								x = math.floor(pos.x + 0.5),
								y = math.floor(pos.y - 0.5),
								z = math.floor(pos.z + 0.5)
							}
							minetest.set_node(p_groundpl, {name = trail_def.name, param2 = get_param2(trail_def)})
						end
					end
				end

				player_pos_previous[player_name] = current_player_pos
			end
		end
	end)
end

-- ABM

if EROSION then
	minetest.register_abm({
		nodenames = {"group:trail_erodes"},
		interval = EROINT,
		chance = EROCHA,
		catch_up = true,
		action = function(pos, node, _, _)
			local nodename = node.name
			local erodes_to = erosion[nodename]
			if erodes_to then
				minetest.set_node(pos, {name = erodes_to})
			else
				minetest.log("error", "[trail] The node " .. nodename .. " is in group trail_erodes but "
					.. " didn't have an erosion target node defined.")
			end
		end
	})
end
