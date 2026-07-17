local flib_locale = require("__flib__.locale")
local item_sounds = require("__base__.prototypes.item_sounds")
local khaosbash = require("__khaosbash__.prototypes.lib")
local khaoslib_entity = require("__khaoslib__.entity")
local khaoslib_item = require("__khaoslib__.item")
local khaoslib_recipe = require("__khaoslib__.recipe")
local khaoslib_technology = require("__khaoslib__.technology")
local util = require("util")

--- @class SushiSplitters
local sushi_splitters = {}

--- @class SushiSplitters.SushiSplitterDefinition
--- @field public name data.EntityID Name of the splitter for which the sushi splitter should be created.
--- @field public item data.ItemID? Name of the item for the named splitter, if different from the entity name. Defaults to the entity name if not set.
--- @field public recipe data.RecipeID? Name of the recipe for the named splitter, if different from the entity name. Defaults to the entity name if not set.
--- @field public tint data.Color Tint for the sushi splitters arrows.
--- @field public unlock data.TechnologyID? Name of the technology that unlocks the sushi splitter recipe. If not set, the recipe will not be added to any technology and will need to be unlocked manually.

--- Create the sushi splitter entity for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.create_entity(def)
  if khaoslib_entity.exists("splitter", def.name) then
    local orig = khaoslib_entity.get("splitter", def.name)
    khaoslib_entity.copy("splitter", def.name, "sushi-" .. def.name)
      :set_icons(khaosbash.load_icons("__khaosbash__/graphics/base/icons/splitter-south", def.tint))
      :set {next_upgrade = orig.next_upgrade and "sushi-" .. orig.next_upgrade or nil}
      :merge_minable {result = "sushi-" .. (def.item or def.name)}
      :commit()
  end
end

--- Create the sushi splitter item for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.create_item(def)
  local item_name = def.item or def.name
  if khaoslib_item.exists(item_name) then
    local orig = khaoslib_item.get(item_name)
    khaoslib_item:load {
      type = "item",
      name = "sushi-" .. item_name,
      subgroup = orig.subgroup,
      order = orig.order .. "-sushi",
      stack_size = orig.stack_size,
      weight = orig.weight,
      place_result = "sushi-" .. def.name,
      inventory_move_sound = item_sounds.mechanical_inventory_move,
      pick_sound = item_sounds.mechanical_inventory_pickup,
      drop_sound = item_sounds.mechanical_inventory_move,
    } :set_icons(khaosbash.load_icons("__khaosbash__/graphics/base/icons/splitter-south", def.tint))
      :commit()
  end
end

--- Create the sushi splitter recipe from original splitter for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.create_recipe(def)
  local recipe_name = def.recipe or def.name

  if khaoslib_recipe.exists(recipe_name) then
    local orig = khaoslib_recipe.get(recipe_name)
    local results = orig.results

    khaoslib_recipe:load {
      type = "recipe",
      name = "sushi-" .. recipe_name,
      enabled = orig.enabled or false,
      energy_required = orig.energy_required or 1,
    } :set_ingredients {
      {type = "item", name = def.item or def.name, amount = 1},
      {type = "item", name = "copper-cable", amount = 1},
    } :set_results {
      {type = "item", name = "sushi-" .. (def.item or def.name), amount = (results and results[1]) and results[1].amount or 1},
    }:set_icons(khaosbash.load_icons("__khaosbash__/graphics/base/icons/splitter-south", def.tint))
      :commit()
  end
end

--- Create the sushi splitter upgrade recipe from previous tier sushi splitter for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.create_upgrade_recipe(def)
  local recipe_name = def.recipe or def.name
  if khaoslib_recipe.exists(recipe_name) then
    local orig = khaoslib_recipe.get(recipe_name)
    local results = orig.results

    local recipe = khaoslib_recipe.copy(recipe_name, "sushi-" .. recipe_name .. "-upgrade")
      :set {localised_name = flib_locale.of("recipe", "sushi-" .. recipe_name)}
      :set_icons(khaosbash.load_icons("__khaosbash__/graphics/base/icons/splitter-south", def.tint))
      :replace_ingredient(function (ingredient)
        --- @diagnostic disable-next-line: param-type-mismatch
        return ingredient.name:match("splitter") ~= nil and ingredient.name:match("sushi") == nil
      end, function (ingredient)
        ingredient.name = "sushi-" .. (def.item or def.name)
        return ingredient
      end, {all = true})
      :set_results {
        {type = "item", name = "sushi-" .. (def.item or def.name), amount = (results and results[1]) and results[1].amount or 1},
      }

    if not recipe:has_ingredient("sushi-" .. (def.item or def.name)) then
      if recipe:has_ingredient("copper-cable") then
        recipe:replace_ingredient("copper-cable", function (ingredient)
          ingredient.amount = ingredient.amount + 1
          return ingredient
        end)
      else
        recipe:add_ingredient {type = "item", name = "copper-cable", amount = 1}
      end
    end

    recipe:commit()
  end
end

--- Create the sushi splitter recycling recipe for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.create_recycling_recipe(def)
  local upgrade_recipe_name = "sushi-" .. (def.recipe or def.name) .. "-upgrade"
  if khaoslib_recipe.count_results(upgrade_recipe_name) ~= 1 then return end

  local orig = khaoslib_recipe.get(upgrade_recipe_name)
  local recipe = khaoslib_recipe:load {
    type = "recipe",
    name = "sushi-" .. (def.recipe or def.name) .. "-recycling",
    category = "recycling",
    localised_name = {"recipe-name.recycling", flib_locale.of("recipe", "sushi-" .. (def.recipe or def.name))},
    hidden = true,
    allow_decomposition = false,
    unlock_results = false,
    energy_required = (orig.energy_required or 0.5) / 16,
  }

  local icons = {{icon = "__quality__/graphics/icons/recycling.png", icon_size = 64}}
  util.combine_icons(icons, khaosbash.load_icons("__khaosbash__/graphics/base/icons/splitter-south", def.tint), {scale = 0.8}, 64)
  table.insert(icons, {icon = "__quality__/graphics/icons/recycling-top.png", icon_size = 64})
  recipe:set_icons(icons)

  local upgrade_results = khaoslib_recipe.get_results(upgrade_recipe_name)
  if khaoslib_item.exists(upgrade_results[1]--[[@cast -?]].name) then
    recipe:set_ingredients {
      {type = "item", name = "sushi-" .. (def.item or def.name), amount = 1},
    }

    --- @type data.RecipeTints
    local result_crafting_tint = {
      primary = {0.5, 0.5, 0.5, 0.5},
      secondary = {0.5, 0.5, 0.5, 0.5},
      tertiary = {0.5, 0.5, 0.5, 0.5},
      quaternary = {0.5, 0.5, 0.5, 0.5},
    }

    for _, ingredient in pairs(khaoslib_recipe.get_ingredients(upgrade_recipe_name)) do
      if ingredient.type == "item" and khaoslib_item.exists(ingredient.name) then
        local amount = ingredient.amount
        local probability = 4 * (upgrade_results[1] and upgrade_results[1].amount or 1) --[[@as integer]]
        local remainder = amount % probability
        amount = (amount / probability) --[[@as integer]] -- not really true, but yeah..
        local extra_fraction = remainder / probability

        recipe:add_result {type = "item", name = ingredient.name, amount = amount, extra_count_fraction = extra_fraction}
      elseif ingredient.type == "fluid" and data.raw["fluid"][ingredient.name] then
        local fluid = data.raw["fluid"][ingredient.name]
        local flow_color = fluid.flow_color
        local normalized_flow_color = {(flow_color[1] or flow_color.r or 0), (flow_color[2] or flow_color.g or 0), (flow_color[3] or flow_color.b or 0)}
        if normalized_flow_color[1] > 1 or normalized_flow_color[2] > 1 or normalized_flow_color[3] > 1 then
          normalized_flow_color[1] = normalized_flow_color[1] / 255
          normalized_flow_color[2] = normalized_flow_color[2] / 255
          normalized_flow_color[3] = normalized_flow_color[3] / 255
        end

        result_crafting_tint.tertiary = {
          normalized_flow_color[1] + ((1 - normalized_flow_color[1])*0.5),
          normalized_flow_color[2] + ((1 - normalized_flow_color[2])*0.5),
          normalized_flow_color[3] + ((1 - normalized_flow_color[3])*0.5)
        }

        result_crafting_tint.quaternary = fluid.base_color
      end
    end

    recipe:set_crafting_machine_tint(result_crafting_tint)
      :commit()
  end
end

--- Add the sushi splitter recipe to the technology that unlocks it for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.add_unlock(def)
  if def.unlock and khaoslib_technology.exists(def.unlock) then
    khaoslib_technology:load(def.unlock)
      :add_unlock_recipe ("sushi-" .. (def.recipe or def.name))
      :add_unlock_recipe ("sushi-" .. (def.recipe or def.name) .. "-upgrade")
      :commit()
  end
end

--- Create the sushi splitter for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.create_sushi_splitter(def)
  sushi_splitters.create_entity(def)
  sushi_splitters.create_item(def)
  sushi_splitters.create_recipe(def)
  sushi_splitters.create_upgrade_recipe(def)

  if mods["quality"] then
    sushi_splitters.create_recycling_recipe(def)
  end

  sushi_splitters.add_unlock(def)
end

--- @param name data.EntityID Name of the splitter for which the sushi splitter should be created.
--- @param item data.ItemID? Name of the item for the named splitter, if different from the entity name. Defaults to the entity name if not set.
--- @param recipe data.RecipeID? Name of the recipe for the named splitter, if different from the entity name. Defaults to the entity name if not set.
--- @param unlock data.TechnologyID? Name of the technology that unlocks the sushi splitter recipe.
function sushi_splitters.remove_sushi_splitter(name, item, recipe, unlock)
  khaoslib_entity.remove("splitter", "sushi-" .. name)
  khaoslib_item.remove("sushi-" .. (item or name))
  khaoslib_recipe.remove("sushi-" .. (recipe or name))
  khaoslib_recipe.remove("sushi-" .. (recipe or name) .. "-upgrade")

  if mods["quality"] and khaoslib_recipe.exists("sushi-" .. (recipe or name) .. "-recycling") then
    khaoslib_recipe.remove("sushi-" .. (recipe or name) .. "-recycling")
  end

  if mods["Flare Stack"] and khaoslib_recipe.exists("item-sushi-" .. (recipe or name) .. "-incineration") then
    khaoslib_recipe.remove("item-sushi-" .. (recipe or name) .. "-incineration")
  end

  if unlock and khaoslib_technology.exists(unlock) then
    khaoslib_technology:load(unlock)
      :remove_unlock_recipe("sushi-" .. (recipe or name))
      :remove_unlock_recipe("sushi-" .. (recipe or name) .. "-upgrade")
      :commit()
  end
end

return sushi_splitters
