--Minetest FOOTPRINTS mod: compatibility file
--This file describes all nodes that can be trampled

local default_modpath = minetest.get_modpath("default")
local S = minetest.get_translator(minetest.get_current_modname())

--mods
local eth = minetest.get_modpath("ethereal")
local farm = minetest.get_modpath("farming")
local farm_redo = false
if farm then
	if farming.mod == "redo" then farm_redo = true end
end
local flo = minetest.get_modpath("flowers")
local moret = minetest.get_modpath("moretrees")
local tech = minetest.get_modpath("technic_worldgen")
local nc = minetest.get_modpath("nc_terrain") and minetest.get_modpath("nc_flora") and minetest.get_modpath("nc_tree")   --TODO: mineclone and nodecore compatibility.
--local mcl = minetest.get_modpath("mcl_core") and minetest.get_modpath("mcl_flowers")   --mcl seems to be harder as it has it's own farming

local cool_trees_list = {"baldcypress", "bamboo", "birch", "cherrytree", "chestnuttree", "clementinetree",
"ebony", "hollytree", "jacaranda", "larch", "lemontree", "mahogany", "maple", "oak",
"palm", "pineapple", "plumtree", "pomegranate"}

--options

local HARDPACK_PROBABILITY = minetest.settings:get("footprints_hardpack_probability") or 0.9 -- Chance walked dirt/grass is worn and compacted to footprints:trail.
local HARDPACK_COUNT = minetest.settings:get("footprints_hardpack_count") or 10 -- Number of times the above chance needs to be passed for soil to compact.
local FOOTPRINTS_EROSION = minetest.settings:get_bool("footprints_trail_erosion", false) -- Allow hard-packed soil to erode back to dirt

local TRAMPLE_CROPS = minetest.settings:get_bool("footprints_trample_farming_crops", true)
local TRAMPLE_SAPLINGS = minetest.settings:get_bool("footprints_trample_saplings", true)
local TRAMPLE_PLOWED_SOIL = minetest.settings:get_bool("footprints_trample_plowed_soil", true)
local TRAMPLE_GRASS = minetest.settings:get_bool("footprints_trample_wild_grass", true)

-- Nodes

--default nodes
if default_modpath then
	-- hard-packed soil
	local footprints_trail_def = {
		tiles = {"footprints_trailtop.png", "default_dirt.png",
			"default_dirt.png^footprints_trailside.png"},
		groups = {crumbly = 2},
		drop = "default:dirt",
		sounds = default.node_sound_dirt_defaults(),
	}
	if FOOTPRINTS_EROSION then
		footprints_trail_def.groups.footprints_erodes = 1
	end
	minetest.register_node("footprints:trail", footprints_trail_def)
	if FOOTPRINTS_EROSION then
		footprints.register_erosion("footprints:trail", "default:dirt")
	end

	-- hard-packed dry soil
	local footprints_dry_trail_def = {
		tiles = {"footprints_trailtop.png", "default_dry_dirt.png",
			"default_dry_dirt.png^footprints_trailside.png"},
		groups = {crumbly = 2},
		drop = "default:dry_dirt",
		sounds = default.node_sound_dirt_defaults(),
	}
	if FOOTPRINTS_EROSION then
		footprints_dry_trail_def.groups.footprints_erodes = 1
	end
	minetest.register_node("footprints:dry_trail", footprints_dry_trail_def)
	if FOOTPRINTS_EROSION then
		footprints.register_erosion("footprints:dry_trail", "default:dry_dirt")
	end

	-- Default dirt

	footprints.register_trample_node("default:dirt", {
		trampled_node_name = "footprints:dirt",
		trampled_node_def_override = {description = S("Dirt with Footprint"),},
		hard_pack_node_name = "footprints:trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("default:dirt_with_grass", {
		trampled_node_name = "footprints:dirt_with_grass",
		trampled_node_def_override = {description = S("Dirt with Grass and Footprint"),},
		hard_pack_node_name = "footprints:trail",
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("default:dirt_with_dry_grass", {
		trampled_node_name = "footprints:dirt_with_dry_grass",
		trampled_node_def_override = {description = S("Dirt with Dry Grass and Footprint"),},
		hard_pack_node_name = "footprints:trail",
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("default:dirt_with_snow", {
		trampled_node_name = "footprints:dirt_with_snow",
		trampled_node_def_override = {description = S("Dirt with Snow and Footprint"),},
		hard_pack_node_name = "footprints:trail",
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("default:dirt_with_rainforest_litter", {
		trampled_node_name = "footprints:dirt_with_rainforest_litter",
		trampled_node_def_override = {description = S("Dirt with Rainforest Litter and Footprint"),},
		hard_pack_node_name = "footprints:trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("default:dirt_with_coniferous_litter", {
		trampled_node_name = "footprints:dirt_with_coniferous_litter",
		trampled_node_def_override = {description = S("Dirt with Coniferous Litter and Footprint"),},
		hard_pack_node_name = "footprints:trail",
		footprint_opacity = 128,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("default:dry_dirt", {
		trampled_node_name = "footprints:dry_dirt",
		trampled_node_def_override = {description = S("Dry Dirt with Footprint"),},
		hard_pack_node_name = "footprints:dry_trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("default:dry_dirt_with_dry_grass", {
		trampled_node_name = "footprints:dry_dirt_with_dry_grass",
		trampled_node_def_override = {description = S("Dry Dirt with Dry Grass and Footprint"),},
		hard_pack_node_name = "footprints:dry_trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	-- Default sand

	footprints.register_trample_node("default:sand", {
		trampled_node_name = "footprints:sand",
		trampled_node_def_override = {description = S("Sand with Footprint"),},
	})

	footprints.register_trample_node("default:desert_sand", {
		trampled_node_name = "footprints:desert_sand",
		trampled_node_def_override = {description = S("Desert Sand with Footprint"),},
	})

	footprints.register_trample_node("default:silver_sand", {
		trampled_node_name = "footprints:silver_sand",
		trampled_node_def_override = {description = S("Silver Sand with Footprint"),},
	})

	footprints.register_trample_node("default:gravel", {
		trampled_node_name = "footprints:gravel",
		trampled_node_def_override = {description = S("Gravel with Footprint"),},
		footprint_opacity = 128,
	})

	-- Default snow

	footprints.register_trample_node("default:snowblock", {
		trampled_node_name = "footprints:snowblock",
		trampled_node_def_override = {description = S("Snow Block with Footprint"),},
		hard_pack_node_name = "default:ice",
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("default:snow", {
		trampled_node_name = "footprints:snow",
		trampled_node_def_override = {description = S("Snow with Footprint"),},
	})
end
	-- Ethereal dirts

if eth then

	local dirts = {
		"Bamboo", "Jungle", "Grove", "Prairie", "Cold",
		"Crystal", "Mushroom", "Fiery", "Gray"--, "Dry"
	}
	
	for n = 1, #dirts do
		
		local desc = dirts[n]
		local name = desc:lower()
		
		footprints.register_trample_node("ethereal:"..name.."_dirt", {
			trampled_node_name = "footprints:ethereal_"..name.."_dirt",
			trampled_node_def_override = {description = S(desc.." Dirt with Footprint"),},
			hard_pack_node_name = "footprints:trail",
			hard_pack_probability = HARDPACK_PROBABILITY,
			hard_pack_count = HARDPACK_COUNT,
		})
	end
	footprints.register_trample_node("ethereal:dry_dirt", {
		trampled_node_name = "footprints:ethereal_dry_dirt",
		trampled_node_def_override = {description = S("Dry Dirt with Footprint"),},
		hard_pack_node_name = "footprints:dry_trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})
end

--NodeCore default nodes
if nc then
	footprints.register_trample_node("nc_terrain:dirt", {
		trampled_node_name = "footprints:dirt",
		trampled_node_def_override = {description = S("Dirt with Footprint"),},
		footprint_opacity = 96,
		--[[hard_pack_node_name = "footprints:trail", --No hardpacked nodes in NodeCore. Maybe later.
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,--]]
	})

	footprints.register_trample_node("nc_terrain:dirt_loose", {
		trampled_node_name = "footprints:dirt_loose",
		trampled_node_def_override = {description = S("Loose Dirt with Footprint"),},
		footprint_opacity = 96,
		hard_pack_node_name = "footprints:dirt",    --loose nodes will be hardpacked to normal, but only ones that can be packed by hand
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("nc_terrain:dirt_with_grass", {
		trampled_node_name = "footprints:dirt_with_grass",
		trampled_node_def_override = {description = S("Dirt with Footprint"),},
		footprint_opacity = 96,
	})

	footprints.register_trample_node("nc_terrain:sand", {
		trampled_node_name = "footprints:sand",
		trampled_node_def_override = {description = S("Sand with Footprint"),},
		footprint_opacity = 96,
	})

	footprints.register_trample_node("nc_terrain:sand_loose", {
		trampled_node_name = "footprints:sand_loose",
		trampled_node_def_override = {description = S("Loose Sand with Footprint"),},
		footprint_opacity = 96,
		hard_pack_node_name = "footprints:sand",
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("nc_terrain:gravel", {
		trampled_node_name = "footprints:gravel",
		trampled_node_def_override = {description = S("Gravel with Footprint"),},
		footprint_opacity = 96,
	})

	footprints.register_trample_node("nc_terrain:gravel_loose", {
		trampled_node_name = "footprints:gravel_loose",
		trampled_node_def_override = {description = S("Loose Gravel with Footprint"),},
		footprint_opacity = 96,
		hard_pack_node_name = "footprints:gravel",
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	--loose cobble won't have a footprinted modification. It's a stone.
	
	--maybe wet concrete could get special footprinted painting, but I need to understand it's api for that. TODO later.

end

--[[ this mod doesn't work in MineClone, because it uses param2 to darken the grass
--MineClone grounds
if mcl then
	
	footprints.register_trample_node("mcl_core:dirt", {
		trampled_node_name = "footprints:dirt",
		trampled_node_def_override = {description = S("Dirt with Footprint"),},
		hard_pack_node_name = "footprints:trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("mcl_core:dirt_with_grass", {
		trampled_node_name = "footprints:dirt_with_grass",
		trampled_node_def_override = {description = S("Dirt with Footprint"),},
		hard_pack_node_name = "footprints:trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("mcl_core:dirt_with_grass_snow", {
		trampled_node_name = "footprints:dirt_with_grass_snow",
		trampled_node_def_override = {description = S("Dirt with Footprint"),},
		hard_pack_node_name = "footprints:trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})

	footprints.register_trample_node("mcl_core:mycelium", {
		trampled_node_name = "footprints:mycelium",
		trampled_node_def_override = {description = S("Dirt with Footprint"),},
		hard_pack_node_name = "footprints:trail",
		footprint_opacity = 96,
		hard_pack_probability = HARDPACK_PROBABILITY,
		hard_pack_count = HARDPACK_COUNT,
	})
end --]]

--Plowed soil
if farm and TRAMPLE_PLOWED_SOIL then
	footprints.register_trample_node("farming:soil", {
		trampled_node_name = "default:dirt",
		probability = 0.2,
		alternate_sneak_q = 0.3
	})
	
	footprints.register_trample_node("farming:soil_wet", {
		trampled_node_name = "default:dirt",
		probability = 0.6,
		alternate_sneak_q = 0.3
	})
end

--Crops
if TRAMPLE_CROPS then
	--support for Ethereal
	if eth then
		
		local crops = {
			onion = 5,
			strawberry = 8,
		}

		for plant, stages in pairs(crops) do
			
			--make all avilable crops trampable

			footprints.register_trampled_plant("ethereal:"..plant, {
				growth_stages = stages,
				trampled_node_name = "footprints:plant",
				numerate_trampled_node = true,
				base_probability = 1.0,
			})
			
		end	
	end

	--also support for farming redo
	if farm then
		
		local crops = {} --make a list of trampleable plants
		if farm_redo then
			crops = {
				artichoke = 4,
				barley = 7,
				beanpole = 5,
				beetroot = 5,
				blackberry = 4,
				blueberry = 4,
				cabbage = 6,
				carrot = 8,
				chili = 8,
				coffee = 5,
				corn = 8,
				cotton = 8,
				cucumber = 4,
				garlic = 5,
				grapes = 8,
				hemp = 8,
				lettuce = 5,
				melon = 7,
				mint = 4,
				onion = 5,
				parsley = 3,
				pea = 5,
				pepper = 7,
				pineapple = 7,
				potato = 4,
				pumpkin = 7,
				raspberry = 4,
				rhubarb = 3,
				rye = 3,
				oat = 3,
				rice = 3,
				soy = 7,
				tomato = 8,
				vanilla = 8,
				wheat = 8
			}
		else
			crops = {
				cotton = 8,
				wheat = 8
			}
		end
		

		for plant, stages in pairs(crops) do
			
			--make all avilable plants trampleable

			footprints.register_trampled_plant("farming:"..plant, {
				growth_stages = stages,
				trampled_node_name = "footprints:plant",
				numerate_trampled_node = true,
				base_probability = 1.0,
			})
		end
	end
end

if default_modpath then
	footprints.register_hoe_converts("footprints:trail", "default:dirt")
	footprints.register_hoe_converts("footprints:dry_trail", "default:dry_dirt")
end


--SAPLINGS
if TRAMPLE_SAPLINGS then
	local saplings = {}
	if default_modpath then
		table.insert(saplings, {name = "default:sapling", prob = 0.5})
		table.insert(saplings, {name = "default:junglesapling", prob = 0.3})
		table.insert(saplings, {name = "default:pine_sapling", prob = 0.3})
		table.insert(saplings, {name = "default:aspen_sapling", prob = 0.3})
		table.insert(saplings, {name = "default:acacia_sapling", prob = 0.9})
		table.insert(saplings, {name = "default:bush_sapling", prob = 0.2})
		table.insert(saplings, {name = "default:blueberry_bush_sapling", prob = 0.8})
		table.insert(saplings, {name = "default:acacia_bush_sapling", prob = 0.7})
		table.insert(saplings, {name = "default:pine_bush_sapling", prob = 0.2})
		table.insert(saplings, {name = "default:emergent_jungle_sapling", prob = 0.9})
	end

	if eth then
		table.insert(saplings, {name = "ethereal:bamboo_sprout", prob = 0.1})
		table.insert(saplings, {name = "ethereal:willow_sapling", prob = 0.4})
		table.insert(saplings, {name = "ethereal:yellow_tree_sapling", prob = 1.0})
		table.insert(saplings, {name = "ethereal:big_tree_sapling", prob = 0.2})
		table.insert(saplings, {name = "ethereal:banana_tree_sapling", prob = 0.3})
		table.insert(saplings, {name = "ethereal:frost_tree_sapling", prob = 0.2})
		table.insert(saplings, {name = "ethereal:mushroom_sapling", prob = 0.5})
		table.insert(saplings, {name = "ethereal:palm_sapling", prob = 0.4})
		table.insert(saplings, {name = "ethereal:redwood_sapling", prob = 0.5})
		table.insert(saplings, {name = "ethereal:orange_tree_sapling", prob = 0.5})
		table.insert(saplings, {name = "ethereal:birch_sapling", prob = 0.3})
		table.insert(saplings, {name = "ethereal:sakura_sapling", prob = 0.9})
		table.insert(saplings, {name = "ethereal:lemon_tree_sapling", prob = 0.8})
		table.insert(saplings, {name = "ethereal:olive_tree_sapling", prob = 0.8})
	end

	if moret then
		for i, tree in ipairs(moretrees.treelist) do
			table.insert(saplings, {name = "moretrees:"..tree[1].."_sapling", prob = 0.5})
		end
	end

	if tech and not moret then
		table.insert(saplings, {name = "moretrees:rubber_tree_sapling", prob = 0.5})
	end


	--cool_trees
	for i, tree in ipairs(cool_trees_list) do
		if minetest.get_modpath(tree) then
			local sapl = "sapling"
			if tree == "bamboo" then sapl = "sprout" end
			table.insert(saplings, {name = tree..":"..sapl, prob = 0.5})	
		end
	end


	--finally register them all
	for i, sapling in ipairs(saplings) do
		footprints.register_trample_node(sapling.name, {
			trampled_node_name = "footprints:plant_4",
			probability = sapling.prob,
		})
	end

	--NodeCore
	if nc then
		footprints.register_trample_node("nc_tree:eggcorn_planted", {
			trampled_node_name = "nc_terrain:dirt",
			trampled_node_def_override = {description = S("Dirt with Footprint"),},
	})
	end
end

if TRAMPLE_GRASS then
	local grasses = {}
	
	--Default MT
	if default_modpath then
		--lower grass
		
		footprints.register_trampled_plant("default:grass", {
			growth_stages = 5,
			trample_to_lower_stage = true,
			base_probability = 0.9,
		})

		--disappearing grasses
		table.insert(grasses, "default:junglegrass")
		table.insert(grasses, "default:dry_shrub")
	end

	--Ethereal
	if eth then
		table.insert(grasses, "ethereal:fern")
		table.insert(grasses, "ethereal:dry_shrub")
		table.insert(grasses, "ethereal:snowygrass")
		table.insert(grasses, "ethereal:crystalgrass")
		table.insert(grasses, "ethereal:firethorn")
		table.insert(grasses, "ethereal:fire_flower")
		table.insert(grasses, "ethereal:illumishroom")
		table.insert(grasses, "ethereal:illumishroom2")
		table.insert(grasses, "ethereal:illumishroom3")
	end

	--Flowers
	if flo then
		table.insert(grasses, "flowers:rose")
		table.insert(grasses, "flowers:tulip")
		table.insert(grasses, "flowers:viola")
		table.insert(grasses, "flowers:geranium")
		table.insert(grasses, "flowers:tulip_black")
		table.insert(grasses, "flowers:dandelion_white")
		table.insert(grasses, "flowers:mushroom_red")
		table.insert(grasses, "flowers:mushroom_brown")
		table.insert(grasses, "flowers:dandelion_yellow")
		table.insert(grasses, "flowers:chrysanthemum_green")

	end

	--NodeCore
	if nc then
		
		footprints.register_trampled_plant("nc_flora:sedge", {
			growth_stages = 5,
			trample_to_lower_stage = true,
			base_probability = 0.9,
		})
		
		table.insert(grasses, "nc_flora:rush")
		table.insert(grasses, "nc_flora:rush_dry")
		for a = 1, 5 do
			for b = 0, 9 do
				table.insert(grasses, "nc_flora:flower_"..a.."_"..b)
			end
		end
	end

	for i, grass in ipairs(grasses) do
		footprints.register_trample_node(grass, {
			trampled_node_name = "air",
			probability = 0.4,
		})
	end
end
