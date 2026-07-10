local flib_locale = require("__flib__.locale")
local item_sounds = require("__base__.prototypes.item_sounds")
local khaoslib_entity = require("__khaoslib__.entity")
local khaoslib_item = require("__khaoslib__.item")
local khaoslib_recipe = require("__khaoslib__.recipe")
local khaoslib_technology = require("__khaoslib__.technology")
local util = require("util")

--- @class SushiSplitters
local sushi_splitters = {}

--- @type data.IconData[]
local default_icons = {
  {icon = "__sushi-splitters__/graphics/icons/sushi-gray-splitter.png", icon_size = 32}
}

--- @class SushiSplitters.SushiSplitterDefinition
--- @field public name data.EntityID Name of the splitter for which the sushi splitter should be created.
--- @field public item data.ItemID? Name of the item for the named splitter, if different from the entity name. Defaults to the entity name if not set.
--- @field public recipe data.RecipeID? Name of the recipe for the named splitter, if different from the entity name. Defaults to the entity name if not set.
--- @field public icons data.IconData[]? Icons for the sushi splitter. Defaults to a generic gray sushi splitter icon if not set.
--- @field public recipe_icons data.IconData[]? Alternative icons for the sushi splitter recipes. Defaults to the same icons as the sushi splitter if not set.
--- @field public unlock_tech data.TechnologyID? Name of the technology that unlocks the sushi splitter recipe. If not set, the recipe will not be added to any technology and will need to be unlocked manually.

--- Create the sushi splitter entity for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.create_entity(def)
  if khaoslib_entity.exists("splitter", def.name) then
    khaoslib_entity:load("splitter", def.name)
      :copy("sushi-" .. def.name)
      :set {minable = {result = "sushi-" .. (def.item or def.name)}}
      :set {next_upgrade = data.raw["splitter"][def.name].next_upgrade and "sushi-" .. data.raw["splitter"][def.name].next_upgrade or nil}
      :commit()
  end
end

--- Create the sushi splitter item for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.create_item(def)
  local item = def.item or def.name
  if khaoslib_item.exists(item) then
    khaoslib_item:load {
      type = "item",
      name = "sushi-" .. item,
      subgroup = data.raw["item"][item].subgroup,
      order = data.raw["item"][item].order .. "-sushi",
      stack_size = data.raw["item"][item].stack_size,
      weight = data.raw["item"][item].weight,
      place_result = "sushi-" .. def.name,
      inventory_move_sound = item_sounds.mechanical_inventory_move,
      pick_sound = item_sounds.mechanical_inventory_pickup,
      drop_sound = item_sounds.mechanical_inventory_move,
    } :set_icons(def.icons or default_icons)
      :commit()
  end
end

--- Create the sushi splitter recipe from original splitter for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.create_recipe(def)
  local recipe = def.recipe or def.name
  if khaoslib_recipe.exists(recipe) then
    khaoslib_recipe:load {
      type = "recipe",
      name = "sushi-" .. recipe,
      enabled = data.raw["recipe"][recipe].enabled or false,
      energy_required = data.raw["recipe"][recipe].energy_required or 1,
    } :set_ingredients {
      {type = "item", name = def.item or def.name, amount = 1},
      {type = "item", name = "copper-cable", amount = 1},
    } :set_results {
      {type = "item", name = "sushi-" .. (def.item or def.name), amount = data.raw["recipe"][recipe].results[1].amount or 1},
    } :set_icons(def.recipe_icons or def.icons or default_icons)
      :commit()
  end
end

--- Create the sushi splitter upgrade recipe from previous tier sushi splitter for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.create_upgrade_recipe(def)
  local recipe = def.recipe or def.name
  if khaoslib_recipe.exists(recipe) then
    local new_recipe = khaoslib_recipe.copy(recipe, "sushi-" .. recipe .. "-upgrade")
      :set {localised_name = flib_locale.of("recipe", "sushi-" .. recipe)}
      :set_icons(def.recipe_icons or def.icons or default_icons)
      :replace_ingredient(function (ingredient)
        return ingredient.name:match("splitter") ~= nil and ingredient.name:match("sushi") == nil
      end, function (ingredient)
        ingredient.name = "sushi-" .. (def.item or def.name)
        return ingredient
      end, {all = true})
      :set_results {
        {type = "item", name = "sushi-" .. (def.item or def.name), amount = data.raw["recipe"][recipe].results[1].amount or 1},
      }

    if not new_recipe:has_ingredient("sushi-" .. (def.item or def.name)) then
      if new_recipe:has_ingredient("copper-cable") then
        new_recipe:replace_ingredient("copper-cable", function (ingredient)
          ingredient.amount = ingredient.amount + 1
          return ingredient
        end)
      else
        new_recipe:add_ingredient {type = "item", name = "copper-cable", amount = 1}
      end
    end

    new_recipe:commit()
  end
end

--- Create the sushi splitter recycling recipe for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.create_recycling_recipe(def)
  local upgrade_recipe_name = "sushi-" .. (def.recipe or def.name) .. "-upgrade"
  if khaoslib_recipe.count_results(upgrade_recipe_name) ~= 1 then return end

  local recipe = khaoslib_recipe:load {
    type = "recipe",
    name = "sushi-" .. (def.recipe or def.name) .. "-recycling",
    category = "recycling",
    localised_name = {"recipe-name.recycling", flib_locale.of("recipe", "sushi-" .. (def.recipe or def.name))},
    hidden = true,
    allow_decomposition = false,
    unlock_results = false,
    energy_required = (data.raw.recipe[upgrade_recipe_name] and data.raw.recipe[upgrade_recipe_name].energy_required or 0.5) / 16,
  }

  local icons = {}
  if #def.icons == 1 then
    icons = {
      {icon = "__quality__/graphics/icons/recycling.png", icon_size = 64},
      {icon = def.icons[1].icon, icon_size = def.icons[1].icon_size, scale = (0.5 * defines.default_icon_size / (def.icons[1].icon_size or defines.default_icon_size)) * 0.8},
      {icon = "__quality__/graphics/icons/recycling-top.png", icon_size = 64},
    }
  else
    icons = {
      {icon = "__quality__/graphics/icons/recycling.png", icon_size = 64},
    }

    for i = 1, #def.icons do
      local icon = table.deepcopy(def.icons[i])
      icon.scale = ((icon.scale == nil) and (0.5 * defines.default_icon_size / (icon.icon_size or defines.default_icon_size)) or icon.scale) * 0.8
      icon.shift = util.mul_shift(icon.shift, 0.8)
      table.insert(icons, icon)
    end

    table.insert(icons, {icon = "__quality__/graphics/icons/recycling-top.png", icon_size = 64})
  end
  recipe:set_icons(icons)

  local upgrade_results = khaoslib_recipe.get_results(upgrade_recipe_name)
  if khaoslib_recipe.exists(upgrade_results[1].name) then
    recipe:set_ingredients {
      {type = "item", name = "sushi-" .. (def.item or def.name), amount = 1},
    }

    local result_crafting_tint = {
      primary = {0.5, 0.5, 0.5, 0.5},
      secondary = {0.5, 0.5, 0.5, 0.5},
      tertiary = {0.5, 0.5, 0.5, 0.5},
      quaternary = {0.5, 0.5, 0.5, 0.5},
    }

    for _, ingredient in pairs(data.raw.recipe[upgrade_recipe_name].ingredients) do
      if ingredient.type == "item" and khaoslib_item.exists(ingredient.name) then
        local amount = ingredient.amount
        local probability = 4 * upgrade_results[1].amount
        local remainder = amount % probability
        amount = amount / probability
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

    recipe:set {crafting_machine_tint = result_crafting_tint}
  end
end

--- Add the sushi splitter recipe to the technology that unlocks it for the given definition.
--- @param def SushiSplitters.SushiSplitterDefinition
function sushi_splitters.add_unlock(def)
  if def.unlock_tech and khaoslib_technology.exists(def.unlock_tech) then
    khaoslib_technology:load(def.unlock_tech)
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

return sushi_splitters
