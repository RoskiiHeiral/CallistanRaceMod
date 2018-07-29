function init(virtual)
	weaponLevelKinds = { --what materials are produced by generated weapons of X level, higher will be as level 6
	[1] = {"ironbar", "ironbar", "tungstenbar", "copperbar"},
	[2] = {"titaniumbar", "titaniumbar", "titaniumbar", "titaniumbar", "silverbar", "silverbar", "ironbar", "copperbar"},
	[3] = {"durasteelbar", "durasteelbar", "durasteelbar", "durasteelbar", "goldbar", "goldbar", "titaniumbar", "silverbar"},
	[4] = {"refinedaegisalt", "refinedferozium", "refinedviolium", "refinedaegisalt", "refinedferozium", "refinedviolium", "diamond", "diamond", "durasteelbar", "goldbar"},
	[5] = {"solariumstar", "solariumstar", "solariumstar", "diamond", "diamond", "diamond", "refinedaegisalt", "refinedferozium", "refinedviolium"}
	}
	weaponTypeOutputAmounts = { --reads weaponType for a string, returns this many random items from weaponLevelKinds
	["dagger"] = 3,
	["short"] = 3,
	["pistol"] = 3,
	["rocket"] = 5,
	["revolver"] = 3,
	["grenade"] = 5,
	["hammer"] = 5,
	["axe"] = 5,
	["fist"] = 3,
	["DEFAULT"] = 4 --rifles, leveled shields, everything else
	}
	manualRecipes = { --custom uncrafts, unaffected by output modifiers
	["shield"] = {["count"] = 300, ["parameters"] = {}, ["name"] = "money"}, 
	["sapling"] = {["count"] = 5, ["parameters"] = {}, ["name"] = "plantfibre"}
	}
	recipeBlacklist = config.getParameter("recipeBlacklist")
	
	
--If you'd like to make recipes for your mod which can't be deconstructed, make a patch for /objects/crafting/recycler/recycler.lua that adds '"itemname" : true' into the "recipeBlacklist" field, or add the "nouncrafting" tag to the recipe.
	
	matterBlacklist = config.getParameter("matterBlacklist")--these materials will not be turned into blessed liquid
	
	matterWeights = { --material:goo conversion ratio
	{"fullwood", 5},
	{"pressurized", 5},
	{"ornate" , 5},
	{"tech", 5},
	{"tomb", 5},
	{"ancient", 5},
	{"metal", 5},
	{"temple", 5},
	{"pipe", 5},
	{"metal", 5},
	{"sand", 20},
	{"slush", 20},
	{"gravel", 20},
	{"dirt", 20},
	{"ash", 20},
	{"clay", 20},
	{"snow", 20},
	{"mud", 20}
	}
	defaultMatterWeight = 10
	recipeOutputMultiplier = 1.0 --return modifier for general (not genreated weapon or maunal recipe) recipe inputs: rounds up
	normalMoneyOutputMultiplier = 0.5 --override return modifier for pixels in recipes
	--printedMoneyOutputMultiplier = 0.2 --override return modifier for pixels from recipes that only have pixels (3d printer selling)
	currentTimer = 30
	currentMaxTimer = 30
end

function update(dt)
	local recipeList = nil
	local itemRecipe = nil
	local outputItems = nil
	local is3dPrinted = false
	local takeAmount = 1
	local inputItem = world.containerItemAt(entity.id(), 0)
	if currentTimer == 0 then
		if inputItem ~= nil and inputItem.count ~= nil and inputItem.count > 0 and type(inputItem.name) == "string" and recipeBlacklist[inputItem.name] ~= true then
			--sb.logInfo("Input item: %s", inputItem)
			recipeList = root.recipesForItem(inputItem.name)
			--sb.logInfo("Recipes: %s", recipeList)
			if recipeList ~= nil and #recipeList > 0 and root.itemType(inputItem.name) ~= "material" then 
				for _,recipe in ipairs(recipeList) do
					itemRecipe = recipe
					if recipe.output.count > inputItem.count then itemRecipe = nil end
					for _,group in pairs(recipe.groups) do
						if group == "nouncrafting" then
							itemRecipe = nil
							break
						end
					end
					if #recipe.input == 0 then itemRecipe = nil end
					if #recipe.input == 1 and recipe.input[1].name == "money" then itemRecipe = nil end
					if itemRecipe ~= nil then break end
				end
				-- if itemRecipe == nil and recipeList[1].output.count <= inputItem.count then
					-- is3dPrinted = true
					-- for _,recipe in ipairs(recipeList) do
						-- itemRecipe = recipe
						-- if recipe.output.count > inputItem.count then itemRecipe = nil end
						-- if #recipe.input == 0 then itemRecipe = nil end
						-- if itemRecipe ~= nil then break end
					-- end
				-- end
			end
			if itemRecipe ~= nil then
				outputItems = {}
				takeAmount = itemRecipe.output.count
				for _,item in ipairs(itemRecipe.input) do
					if item.count > 0 then
						if item.name == "money" then
							local tempItem = item
							-- if is3dPrinted then
								-- tempItem.count = math.max(math.floor(tempItem.count*printedMoneyOutputMultiplier),1)
							-- else
								tempItem.count = math.max(math.floor(tempItem.count*normalMoneyOutputMultiplier),1)
							--end
							table.insert(outputItems, tempItem)
						else
						    local tempItem = item
							tempItem.count = math.ceil(recipeOutputMultiplier*tempItem.count)
							table.insert(outputItems, tempItem)
						end
					end
				end
			end
			if outputItems ~= nil and #outputItems > 0 then
				--sb.logInfo("Output: %s", outputItems)
				uncraftInput(outputItems, takeAmount)
			else
				processOtherItems(inputItem)
			end
		elseif currentMaxTimer ~= 30 then
			currentMaxTimer = 30
		end
		currentTimer = currentMaxTimer
	else
		currentTimer = currentTimer - 1
	end
end

function processOtherItems(inputItem)
	local outputList = {}
	--sb.logInfo(root.itemType(inputItem.name))
	if root.itemHasTag(inputItem.name, "weapon") or root.itemHasTag(inputItem.name, "shield") or (inputItem.parameters.level ~= nil and inputItem.parameters.tooltipKind == "shield") then
		local weaponLevel = inputItem.parameters.level or root.itemConfig(inputItem.name).level or 1
		weaponLevel = math.max(math.min(math.ceil(weaponLevel), 5), 1)
		local outputKind = weaponLevelKinds[weaponLevel] or "ironbar"
		local outputAmount = determineOutputAmount(inputItem)
		if type(outputKind) == "table" then
			local outputAmountList = {}
			for n=1,#outputKind do
				outputAmountList[n] = 0
			end
			for u=1,outputAmount do
				local kind = math.random(#outputKind)
				outputAmountList[kind] = outputAmountList[kind] + 1 
			end
			for i=1, #outputAmountList do
				if outputAmountList[i] > 0 then
					table.insert(outputList, {["count"] = outputAmountList[i], ["parameters"] = {}, ["name"] = outputKind[i]})
				end
			end
		else
			outputList[1] = {["count"] = outputAmount, ["parameters"] = {}, ["name"] = outputKind}
		end		
		uncraftInput(outputList,1)
	elseif inputItem.parameters.tooltipKind == "shield" then
		outputList[1] = manualRecipes.shield
		uncraftInput(outputList,1)
	elseif inputItem.name == "sapling" then
		outputList[1] = manualRecipes.sapling
		uncraftInput(outputList,1)
	elseif inputItem.name == "liquidcallisto" or inputItem.name == "matterblock" then
		preformMaterialConversion()
	elseif root.itemType(inputItem.name) == "material" and matterBlacklist[inputItem.name] ~= true then
		local matterRatio = determineMatterAmount(inputItem.name)
		if type(matterRatio) == "number" and inputItem.count >= matterRatio then
			uncraftInput({{["count"] = 1, ["parameters"] = {}, ["name"] = "liquidcallisto"}}, matterRatio)
		end
	else
		return false
	end
end

function uncraftInput(output, takeNum)
	local storedSlots = {}
	if currentMaxTimer < 2 then
	elseif currentMaxTimer < 11 then
		currentMaxTimer = currentMaxTimer - 1
	else
		currentMaxTimer = currentMaxTimer - 2
	end
	for i=1,9 do
		storedSlots[i] = world.containerItemAt(entity.id(), i-1)
	end
	--sb.logInfo("Stored: %s", storedSlots)
	for _,item in ipairs(output) do
		local returnStack = world.containerAddItems(entity.id(), item)
		--sb.logInfo("Placing %s: returns %s", item, returnStack)
		if returnStack ~= nil and returnStack.count ~= nil then
			world.containerTakeAll(entity.id())
			--sb.logInfo("Replacing Contents")
			for i=1,9 do
				if storedSlots[i] ~= nil and storedSlots[i].count ~= nil then
					--sb.logInfo("Placing %s at %s: %s", storedSlots[i], i-1, world.containerPutItemsAt(entity.id(), storedSlots[i], i-1))
					world.containerPutItemsAt(entity.id(), storedSlots[i], i-1)
				end
			end
			currentMaxTimer = 30
			return nil
		end
	end
	local takenItems = world.containerTakeAt(entity.id(), 0)
	--sb.logInfo("Taken: %s", takenItems)
	if takenItems ~= nil and takenItems.count ~= nil then
		if takenItems.count > 1 then
			takenItems.count = takenItems.count - takeNum
			--sb.logInfo("Putting Back: %s", takenItems.count)
			world.containerPutItemsAt(entity.id(), takenItems, 0)
		end
	end
end

function determineMatterAmount(name)
	local outAmount = defaultMatterWeight
	for _,i in ipairs(matterWeights) do
		if string.find(name, i[1]) ~= nil then
			outAmount = i[2]
			break
		end
	end
	return outAmount or defaultMatterWeight
end

function determineOutputAmount(item)
	local outAmount = weaponTypeOutputAmounts.DEFAULT
	local itemType = item.parameters.weaponType or root.itemConfig(item.name).config.weaponType or "shield"
	if string.find(itemType, "dagger") ~= nil or string.find(itemType, "Dagger") ~= nil then
		outAmount = weaponTypeOutputAmounts.dagger
	elseif string.find(itemType, "short") ~= nil or string.find(itemType, "Short") ~= nil then
		outAmount = weaponTypeOutputAmounts.short
	elseif string.find(itemType, "pistol") ~= nil or string.find(itemType, "Pistol") ~= nil then
		outAmount = weaponTypeOutputAmounts.pistol
	elseif string.find(itemType, "rocket") ~= nil or string.find(itemType, "Rocket") ~= nil then
		outAmount = weaponTypeOutputAmounts.rocket
	elseif string.find(itemType, "revolver") ~= nil or string.find(itemType, "Revolver") ~= nil then
		outAmount = weaponTypeOutputAmounts.revolver
	elseif string.find(itemType, "grenade") ~= nil or string.find(itemType, "Grenade") ~= nil then
		outAmount = weaponTypeOutputAmounts.grenade
	elseif string.find(itemType, "hammer") ~= nil or string.find(itemType, "Hammer") ~= nil then
		outAmount = weaponTypeOutputAmounts.hammer
	elseif string.find(itemType, "axe") ~= nil or string.find(itemType, "Axe") ~= nil then
		outAmount = weaponTypeOutputAmounts.axe
	elseif string.find(itemType, "fist") ~= nil or string.find(itemType, "Fist") ~= nil then
		outAmount = weaponTypeOutputAmounts.fist
	end
	return outAmount
end

function preformMaterialConversion()
	local slotMaterials = {}
	local outItem = nil
	for i=1,8 do
		local item = world.containerItemAt(entity.id(), i)
		--sb.logInfo("%s", item)
		if type(item) == "table" and item.name ~= "matterblock" and root.itemType(item.name) == "material" then
			outItem = item
			outItem.count = 1
			if world.containerItemsCanFit(entity.id(), outItem) > 0 then 
				uncraftInput({{["count"] = 1, ["parameters"] = item.parameters, ["name"] = item.name}}, 1)
				break
			end
		end
	end
	return nil
end

function reverseTable(inTable)
	local outTable = {}
	if type(inTable) == "table" then
		outTable = {}
		for i = #inTable, 1, -1 do 
			table.insert(outTable, inTable[i])
		end
	end
	return outTable
end

function die()

end
