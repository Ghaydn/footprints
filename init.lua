--Minetest FOOTPRINTS mod: compatibility file
--This file contents core functionality

-- global callbacks
footprints = {}

local default_modpath = minetest.get_modpath("default")

local S = minetest.get_translator(minetest.get_current_modname())

-- Parameters

local GLOBALSTEP_INTERVAL = 0.2 -- Function cycle in seconds.

local EROSION = minetest.settings:get_bool("footprints_erosion", true) -- Enable footprint erosion.
local EROSION_INTERVAL = minetest.settings:get("footprints_erosion_interval") or 128 -- Erosion interval.
local EROSION_CHANCE = minetest.settings:get("footprints_erosion_chance") or 2 -- Erosion 1/x chance.
local SQUARED_PROBABILITIES = minetest.settings:get_bool("footprints_squared_probabilities", true)
local SNEAK_Q = minetest.settings:get("footprints_sneak_coefficient") or 0.5

-- Utility

local sounds
if default_modpath then
	sounds = default.node_sound_leaves_defaults()
end

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

local trampleable_nodes = {}
local erosion = {}

footprints.register_trample_node = function(trampleable_node_name, trample_def)
	trample_def = trample_def or {} -- Everything has defaults, so if no trample_def is passed in just use an empty table.

	if trampleable_nodes[trampleable_node_name] then
		minetest.log("error", "[footprints] Attempted to call footprints.register_trample_node to register trampleable node "
			.. trampleable_node_name ..", which has already been registered as trampleable.")
		return			
	end
	local trampleable_node_def = minetest.registered_nodes[trampleable_node_name]
	if trampleable_node_def == nil then
		minetest.log("error", "[footprints] Attempted to call footprints.register_trample_node with the trampleable node "
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
			groups.footprints_erodes = 1
			trampled_node_def.groups = groups
			erosion[trampled_node_name] = trampleable_node_name
		end
		
		-- If the source node doesn't have a special drop, then set drop to drop a source node rather than dropping a node with a footstep.
		if trampled_node_def.drop == nil then
			trampled_node_def.drop = trampleable_node_name
		end
		
		-- Modify the +Y tile with a footprint overlay
		if trample_def.add_footprint_overlay ~= false then
			local footprint_overlay = trample_def.footprint_overlay or "footprints_footprint.png"
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
		
		-- If hard pack has been defined for this footprints type, add it
		local hard_pack_node_name = trample_def.hard_pack_node_name
		if hard_pack_node_name then
			local hard_pack_probability = trample_def.hard_pack_probability or 0.1
			local hard_pack_count = trample_def.hard_pack_count or 1
			trampleable_nodes[trampled_node_name] = {name=hard_pack_node_name, probability=hard_pack_probability, count = hard_pack_count}
		end
	end	

	local probability = trample_def.probability or 1
	local trample_count = trample_def.trample_count or 1
	trampleable_nodes[trampleable_node_name] = {name=trampled_node_name, probability=probability, randomize_trampled_param2 = trample_def.randomize_trampled_param2, count = trample_count}
end

footprints.register_erosion = function(source_node_name, destination_node_name)
	if not EROSION then
		return
	end
	
	if minetest.registered_nodes[source_node_name] == nil then
		minetest.log("error", "[footprints] attempted to call footprints.register_erosion with unregistered source node "
			.. source_node_name)
		return
	end
	if minetest.registered_nodes[destination_node_name] == nil then
		minetest.log("error", "[footprints] attempted to call footprints.register_erosion with unregistered destination node "
			.. destination_node_name)
		return	
	end
	if minetest.get_item_group(source_node_name, "footprints_erodes") == 0 then
		minetest.log("error", "[footprints] attempted to call footprints.register_erosion with source node "
			.. destination_node_name .. " that wasn't in group footprints_erodes.")
		return
	end
	
	erosion[source_node_name] = destination_node_name
end

footprints.register_trampled_plant = function(plant_name, plant_def)
	plant_def = plant_def or {}

	trampled_node_name = plant_def.trampled_node_name or "air"
	base_probability = plant_def.base_probability or 1.0
	stages = plant_def.growth_stages or 1

	if stages >= 2 then
		for growth = 2, stages do
			local tnode_name = trampled_node_name
			local probab = base_probability

			if plant_def.numerate_trampled_node then
				tnode_name = trampled_node_name.."_"..(stages + 1 - growth)
				probab = base_probability * (stages + 1 - growth) / stages
			end
			if plant_def.trample_to_lower_stage then
				tnode_name = plant_name.."_"..(growth-1)
				probab = base_probability
			end

			footprints.register_trample_node(plant_name.."_"..growth, {
				trampled_node_name = tnode_name,
				randomize_trampled_param2 = true,
				probability = probab,
			})
		end
	end
	local unode_name = trampled_node_name
	local probac = base_probability
	
	if plant_def.numerate_trampled_node then
		unode_name = trampled_node_name.."_1"
		--probac = base_probability / stages
	end

	footprints.register_trample_node(plant_name.."_1", {
		trampled_node_name = unode_name,
		randomize_trampled_param2 = true,
		probability = probac,
	})
end

--FARMABLE CROPS
--no matter what plant it was, it will be trampled anyway. But small plants must leave small nodes
for size = 1, 9 do
	local s = (9 - size) / 8
	--create trampled nodes
	minetest.register_node("footprints:plant_"..size, {
		description = S("Flattened Plant"),
		tiles = {"footprints_flat_cotton.png"},
		inventory_image = "footprints_flat_cotton.png",
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "facedir",
		buildable_to = true,
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5*s, -0.5, -0.5*s, 0.5*s, -3 / 8, 0.5*s}
			},
		},
		groups = {snappy = 3, flammable = 2, attached_node = 1},
		drop = "",
		sounds = sounds,
	})
end

-- Allow hoes to turn hardpack back into bare dirt
local hoe_converts_nodes = {}
footprints.register_hoe_converts = function(target_node, converted_node)
	hoe_converts_nodes[target_node] = converted_node
end


--all trampleable nodes were moved to a separate file.
dofile(minetest.get_modpath(minetest.get_current_modname()).."/mods.lua")


--now adding all hoe converts
if minetest.get_modpath("farming") then
	
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
	footprints.register_hoe_converts = function(target_node, converted_node)
	end
end


-- Globalstep function

local timer = 0

local get_param2 = function(footprints_def)
	if footprints_def.randomize_trampled_param2 then
		return math.random(0,3)
	end
	return 0
end

local test_trample_count = function(footprints_def, pos)
	local target_count = footprints_def.count
	if target_count <= 1 then
		return true
	end
	local meta = minetest.get_meta(pos)
	local trampled_count = meta:get_int("footprints_trample_count")
	trampled_count = trampled_count + 1
	if trampled_count >= target_count then
		return true
	end
	meta:set_int("footprints_trample_count", trampled_count)
	return false
end

--this shortcut does not shorten any cut. Does changing dot to underscore change anything?
--local math.floor = math.floor


--this is where all magic happens
--I've made so many comments down there to help myself to understand how it works
minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer > GLOBALSTEP_INTERVAL then
		timer = 0
		for _, player in ipairs(minetest.get_connected_players()) do
			local pos = player:get_pos()
			local player_name = player:get_player_name()
			local pos_x_plus_half = math.floor(pos.x + 0.5)
			local pos_z_plus_half = math.floor(pos.z + 0.5)
			local pos_y = math.floor(pos.y + 0.2) --Changed this offset to 0.4 (was 0.2 andnot here) after rewriting some code
			local current_player_pos = { --where player really is
				x = pos_x_plus_half,
				y = pos_y,
				z = pos_z_plus_half
			}
			
			--movement part. Let's finish it quickly
			local player_pos_previous = player_pos_previous_map[player_name]  --where player was last step
			if player_pos_previous == nil then
				break
			end
			player_pos_previous_map[player_name] = current_player_pos
			--formalities are settled, we now can continue

			--main part
			if current_player_pos.x ~= player_pos_previous.x or --so player has moved horizontally
				current_player_pos.y < player_pos_previous.y or  --or fell down
				current_player_pos.z ~= player_pos_previous.z then
				
				local pos_ground_cover = { --ground cover is what's on the ground: grass, snow
					x = pos_x_plus_half,
					y = pos_y + 1,
					z = pos_z_plus_half
				}
				local name_ground_cover = minetest.get_node(pos_ground_cover).name --how is it named
				
				-- test ground cover first (snow, grass)
				-- by some reason this part don't work correctly
				local footprints_def = trampleable_nodes[name_ground_cover] --is it trampleable at all
				if footprints_def then
					local prob = footprints_def.probability
					
					if player:get_player_control().sneak then
						if footprints_def.alternate_sneak_q then prob = prob * footprints_def.alternate_sneak_q
						else prob = prob * SNEAK_Q end
					end
					if SQUARED_PROBABILITIES then prob = prob^2 end
					if math.random() <= prob then -- trow the dice
						--[[local pos_ground_cover = {  --we don't really need this as we already know where the ground cover is
							x = pos_x_plus_half,
							y = pos_y,  --math.floor(pos_y + 0.3),
							z = pos_z_plus_half
						} --]]
						if test_trample_count(footprints_def, pos_ground_cover) then
							minetest.set_node(pos_ground_cover, {name = footprints_def.name, param2 = get_param2(footprints_def)})
						end
					end
				else
					local pos_ground = { --now see what's on the ground
						x = pos_x_plus_half,
						y = pos_y,
						z = pos_z_plus_half
					}
					local name_ground = minetest.get_node(pos_ground).name --how is ground named

					
					local ground_def = trampleable_nodes[name_ground] -- is it trampleable at all
					if ground_def then
						local proba = ground_def.probability
						if player:get_player_control().sneak then
							if ground_def.alternate_sneak_q then proba = proba * ground_def.alternate_sneak_q
							else proba = proba * SNEAK_Q end
						end
						if SQUARED_PROBABILITIES then proba = proba^2 end
						if math.random() <= proba then --throw the dice
							--skipped the same part here
							if test_trample_count(ground_def, pos_ground) then
								minetest.set_node(pos_ground, {name = ground_def.name, param2 = get_param2(ground_def)})
							end
						end
					end
				end
			end
		end
	end
end)

-- ABM

if EROSION then
	minetest.register_abm({
		nodenames = {"group:footprints_erodes"},
		interval = EROSION_INTERVAL,
		chance = EROSION_CHANCE,
		catch_up = true,
		action = function(pos, node, _, _)
			local nodename = node.name
			local erodes_to = erosion[nodename]
			if erodes_to then
				local meta = minetest.get_meta(pos)
				local trampled_count = meta:get_int("footprints_trample_count") - 1
				if trampled_count <= 0 then
					minetest.set_node(pos, {name = erodes_to})
				else
					meta:set_int("footprints_trample_count", trampled_count)
				end				
			else
				minetest.log("error", "[footprints] The node " .. nodename .. " is in group footprints_erodes but "
					.. " didn't have an erosion target node defined.")
			end
		end
	})
end

minetest.register_alias("nc_footprints:dirt",					"footprints:dirt")
minetest.register_alias("nc_footprints:dirt_with_grass",			"footprints:dirt_with_grass")
minetest.register_alias("nc_footprints:dirt_loose",				"footprints:dirt_loose")
minetest.register_alias("nc_footprints:sand",					"footprints:sand")
minetest.register_alias("nc_footprints:sand_loose",				"footprints:sand_loose")
minetest.register_alias("nc_footprints:gravel",					"footprints:gravel")
minetest.register_alias("nc_footprints:gravel_loose",				"footprints:gravel_loose")
minetest.register_alias("nc_footprints:trail",					"footprints:dirt_with_grass")
minetest.register_alias("footprints:plant",					"footprints:plant_8")
minetest.register_alias("footprints:cotton",					"footprints:plant_8")
minetest.register_alias("trail:cotton",						"footprints:plant_8")
minetest.register_alias("trail:desert_sand",					"footprints:desert_sand")
minetest.register_alias("trail:dirt",						"footprints:dirt")
minetest.register_alias("trail:dirt_with_coniferous_litter",			"footprints:dirt_with_coniferous_litter")
minetest.register_alias("trail:dirt_with_dry_grass",				"footprints:dirt_with_dry_grass")
minetest.register_alias("trail:dirt_with_grass",				"footprints:dirt_with_grass")
minetest.register_alias("trail:dirt_with_rainforest_litter",			"footprints:dirt_with_rainforest_litter")
minetest.register_alias("trail:dirt_with_snow",					"footprints:dirt_with_snow")
minetest.register_alias("trail:dry_dirt",					"footprints:dry_dirt")
minetest.register_alias("trail:dry_dirt_with_dry_grass",			"footprints:dry_dirt_with_dry_grass")
minetest.register_alias("trail:dry_trail",					"footprints:dry_trail")
minetest.register_alias("trail:gravel",						"footprints:gravel")
minetest.register_alias("trail:sand",						"footprints:sand")
minetest.register_alias("trail:silver_sand",					"footprints:silver_sand")
minetest.register_alias("trail:snow",						"footprints:snow")
minetest.register_alias("trail:snowblock",					"footprints:snowblock")
minetest.register_alias("trail:trail",						"footprints:trail")
minetest.register_alias("trail:wheat",						"footprints:plant_8")
