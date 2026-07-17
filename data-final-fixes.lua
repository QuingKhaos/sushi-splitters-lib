local khaoslib_entity = require("__khaoslib__.prototypes.entity")
local khaoslib_item = require("__khaoslib__.prototypes.item")
local khaoslib_recipe = require("__khaoslib__.prototypes.recipe")
local khaoslib_technology = require("__khaoslib__.prototypes.technology")

-- Clean up defective upgrade recipes, where their previous sushi splitter ingredient is gone
local sushi_splitters_recipes = khaoslib_recipe.find(function (recipe)
  return recipe.name:match("sushi(.*)splitter") ~= nil and recipe.name:match("upgrade") == nil and recipe.name:match("recycling") == nil and recipe.name:match("incineration") == nil
end)

for _, recipe_name in pairs(sushi_splitters_recipes) do
  for _, ingredient in pairs(khaoslib_recipe.get_ingredients(recipe_name .. "-upgrade")) do
    --- @diagnostic disable-next-line: param-type-mismatch
    if ingredient.name:match("sushi(.*)splitter") ~= nil and not khaoslib_item.exists(ingredient.name) then
      log("Removing defective recipe " .. recipe_name .. "-upgrade because its ingredient " .. ingredient.name .. " is gone.")
      khaoslib_recipe.remove(recipe_name .. "-upgrade")

      -- Simplify recycling recipe
      if mods["quality"] then
        khaoslib_recipe:load(recipe_name .. "-recycling")
          :set_results {
            {type = "item", name = recipe_name, amount = 1, probability = 0.25}
          } :commit()
      end

      local unlock_techs = khaoslib_technology.find(function (technology)
        return khaoslib_technology.has_unlock_recipe(technology, recipe_name .. "-upgrade")
      end)

      for _, tech_name in pairs(unlock_techs) do
        log("Removing unlock of defective recipe " .. recipe_name .. "-upgrade from technology " .. tech_name)
        khaoslib_technology:load(tech_name):remove_unlock_recipe(recipe_name .. "-upgrade"):commit()
      end

      break
    end
  end
end

-- Cleanup defective upgrade paths, when the next upgrade entity is gone
local sushi_splitters_entities = khaoslib_entity.find("splitter", function (entity)
  return entity.name:match("sushi(.*)splitter") ~= nil
end)

for _, entity_name in pairs(sushi_splitters_entities) do
  local next_upgrade = khaoslib_entity.get("splitter", entity_name).next_upgrade
  if next_upgrade ~= nil and not khaoslib_entity.exists("splitter", next_upgrade) then
    log("Removing defective upgrade path from " .. entity_name .. " to " .. next_upgrade .. " because the next upgrade is gone.")
    khaoslib_entity:load("splitter", entity_name):unset("next_upgrade"):commit()
  end
end
