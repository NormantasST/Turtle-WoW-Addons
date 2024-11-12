-- extra info on GameTooltip and ItemRefTooltip
local AtlasLootTip = CreateFrame("Frame", "AtlasLootTip", GameTooltip)

local GREY = "|cff999999"

local lastSearchName = nil
local lastSearchLink = nil
local function GetItemLinkByName(name)
	if name ~= lastSearchName then
    	for itemID = 1, 90000 do
      		local itemName, hyperLink, itemQuality = GetItemInfo(itemID)
      		if (itemName and itemName == name) then
        		local _, _, _, hex = GetItemQualityColor(tonumber(itemQuality))
        		lastSearchLink = hex.. "|H"..hyperLink.."|h["..itemName.."]|h|r"
     		end
    	end
		lastSearchName = name
  	end
	return lastSearchLink
end

local HookSetItemRef = SetItemRef
SetItemRef = function(link, text, button)
    local item, _, id = string.find(link, "item:(%d+):.*")
	ItemRefTooltip.itemID = id
    HookSetItemRef(link, text, button)
    if not IsShiftKeyDown() and not IsControlKeyDown() and item then
        AtlasLootTip.extendTooltip(ItemRefTooltip, "ItemRefTooltip")
    end
end

local HookSetHyperlink = GameTooltip.SetHyperlink
function GameTooltip.SetHyperlink(self, arg1)
  if arg1 then
    local _, _, linktype = string.find(arg1, "^(.-):(.+)$")
    if linktype == "item" then
        local _, _, id = string.find(arg1,"item:(%d+):.*")
  		GameTooltip.itemID = id
    end
  end
  return HookSetHyperlink(self, arg1)
end

local HookSetBagItem = GameTooltip.SetBagItem
function GameTooltip.SetBagItem(self, container, slot)
	if GetContainerItemLink(container, slot) then
		local _, _, id = string.find(GetContainerItemLink(container, slot),"item:(%d+):.*")
		GameTooltip.itemID = id
	end
  return HookSetBagItem(self, container, slot)
end

local HookSetInboxItem = GameTooltip.SetInboxItem
function GameTooltip.SetInboxItem(self, mailID, attachmentIndex)
	local itemName = GetInboxItem(mailID)
	if itemName then
		local _, _, id = string.find(GetItemLinkByName(itemName),"item:(%d+):.*")
		GameTooltip.itemID = id
	end
	return HookSetInboxItem(self, mailID, attachmentIndex)
end

local HookSetInventoryItem = GameTooltip.SetInventoryItem
function GameTooltip.SetInventoryItem(self, unit, slot)
	if GetInventoryItemLink(unit, slot) then
		local _, _, id = string.find(GetInventoryItemLink(unit, slot),"item:(%d+):.*")
		GameTooltip.itemID = id
	end
	return HookSetInventoryItem(self, unit, slot)
end

local HookSetCraftItem = GameTooltip.SetCraftItem
function GameTooltip.SetCraftItem(self, skill, slot)
	if GetCraftReagentItemLink(skill, slot) then
		local _, _, id = string.find(GetCraftReagentItemLink(skill, slot),"item:(%d+):.*")
		GameTooltip.itemID = id
	end
	return HookSetCraftItem(self, skill, slot)
end

local HookSetTradeSkillItem = GameTooltip.SetTradeSkillItem
function GameTooltip.SetTradeSkillItem(self, skillIndex, reagentIndex)
	if reagentIndex then
		if GetTradeSkillReagentItemLink(skillIndex, reagentIndex) then
			local _, _, id = string.find(GetTradeSkillReagentItemLink(skillIndex, reagentIndex),"item:(%d+):.*")
			GameTooltip.itemID = id
		end
	else
		if GetTradeSkillItemLink(skillIndex) then
			local _, _, id = string.find(GetTradeSkillItemLink(skillIndex),"item:(%d+):.*")
			GameTooltip.itemID = id
		end
	end
	return HookSetTradeSkillItem(self, skillIndex, reagentIndex)
end

local HookSetAuctionItem = GameTooltip.SetAuctionItem
function GameTooltip.SetAuctionItem(self, atype, index)
	local itemName = GetAuctionItemInfo(atype, index)
	if itemName then
		local _, _, id = string.find(GetItemLinkByName(itemName),"item:(%d+):.*")
		GameTooltip.itemID = id
	end
	return HookSetAuctionItem(self, atype, index)
end

local HookSetAuctionSellItem = GameTooltip.SetAuctionSellItem
function GameTooltip.SetAuctionSellItem(self)
	local itemName = GetAuctionSellItemInfo()
	if itemName then
		local _, _, id = string.find(GetItemLinkByName(itemName),"item:(%d+):.*")
		GameTooltip.itemID = id
	end
	return HookSetAuctionSellItem(self)
end

local HookSetTradePlayerItem = GameTooltip.SetTradePlayerItem
function GameTooltip.SetTradePlayerItem(self, index)
	if GetTradePlayerItemLink(index) then
		local _, _, id = string.find(GetTradePlayerItemLink(index),"item:(%d+):.*")
		GameTooltip.itemID = id
	end
	return HookSetTradePlayerItem(self, index)
end

local HookSetTradeTargetItem = GameTooltip.SetTradeTargetItem
function GameTooltip.SetTradeTargetItem(self, index)
	if GetTradeTargetItemLink(index) then
		local _, _, id = string.find(GetTradeTargetItemLink(index),"item:(%d+):.*")
		GameTooltip.itemID = id
	end
	return HookSetTradeTargetItem(self, index)
end

local lastItemName, lastItemID, lastSourceStr, lastDropRate
function AtlasLootTip.extendTooltip(tooltip, tooltipTypeStr)
	if AtlasLootCharDB.ShowSource ~= true then return end
	local originalTooltip = {}
    local itemName = getglobal(tooltipTypeStr .. "TextLeft1"):GetText()
	local line2 = getglobal(tooltipTypeStr .. "TextLeft2")
	local craftSpell, source, sourceStr, dropRate
	local isCraft = false
	local isWBLoot = false
    local isPvP = false
	local isRepReward = false
	local isSetPiece = false
	local isWorldEvent = false
	if itemName and itemName ~= "Fashion Coin" and tooltip.itemID then
		if itemName ~= lastItemName or tooltip.itemID ~= lastItemID then
			for row = 1, 30 do
				local tooltipRowLeft = getglobal(tooltipTypeStr .. 'TextLeft' .. row)
				if tooltipRowLeft then
					local rowtext = tooltipRowLeft:GetText()
					if rowtext then
						originalTooltip[row] = {}
						originalTooltip[row].text = rowtext
					end
				end
			end
			for row=1, table.getn(originalTooltip) do
				if string.find(originalTooltip[row].text, "—",1,true) then -- skip items that state which rep they require
					return
				end
			end
			-- first check if its craftable item
			for k,v in pairs(GetSpellInfoAtlasLootDB["craftspells"]) do
				if v["craftItem"] == tonumber(tooltip.itemID) then
					craftSpell = "s"..tostring(k)
				end
			end
			for k1,v1 in pairs(AtlasLoot_Data["AtlasLootCrafting"]) do
				for k2,v2 in pairs(AtlasLoot_Data["AtlasLootCrafting"][k1]) do
					if v2[1] ~= 0 and v2[1] ~= "" and string.sub(v2[1], 1, 1) ~= "e" then
						if (v2[1] == craftSpell or v2[1] == tonumber(tooltip.itemID))
						and
						(string.find(k1, "Apprentice",1,true) or
						string.find(k1, "Journeyman",1,true) or
						string.find(k1, "Expert",1,true) or
						string.find(k1, "Artisan",1,true) or
						string.find(k1, "Goblin",1,true) or
						string.find(k1, "Gnomish",1,true) or
						string.find(k1, "Survival",1,true) or
						string.find(k1, "Herbalism",1,true) or
						string.find(k1, "FirstAid",1,true) or
						string.find(k1, "Poisons",1,true) or
						string.find(k1, "Mining",1,true) or
						string.find(k1, "Smelting",1,true) or
						string.find(k1, "Elemental",1,true) or
						string.find(k1, "Tribal",1,true) or
						string.find(k1, "Dragonscale",1,true)or
						string.find(k1, "Weaponsmith",1,true)or
						string.find(k1, "Axesmith",1,true)or
						string.find(k1, "Hammersmith",1,true)or
						string.find(k1, "Swordsmith",1,true)or
						string.find(k1, "Armorsmith",1,true)or
						string.find(k1, "Gemology",1,true)or
						string.find(k1, "Goldsmithing",1,true))
						then
							source = k1
							isCraft = true
							lastDropRate = nil
						end
					end
				end
			end
			-- check if its world boss loot
			if not isCraft then
                for k1,v1 in pairs(AtlasLoot_Data["AtlasLootWBItems"]) do
					for k2,v2 in pairs(AtlasLoot_Data["AtlasLootWBItems"][k1]) do
						if v2[1] == tonumber(tooltip.itemID) and string.find(v2[3], itemName, 1, true) then
							source = k1
							isWBLoot = true
                            if v2[5] then
                                dropRate = v2[5]
                                lastDropRate = dropRate
                            else
                                lastDropRate = nil
                            end
						end
					end
				end
			end
            -- check if its a pvp reward
            if not isCraft and not isWBLoot then
                for k1,v1 in pairs(AtlasLoot_Data["AtlasLootGeneralPvPItems"]) do
					for k2,v2 in pairs(AtlasLoot_Data["AtlasLootGeneralPvPItems"][k1]) do
						if v2[1] == tonumber(tooltip.itemID) and string.find(v2[3], itemName, 1, true) then
							source = k1
							isPvP = true
                            lastDropRate = nil
						end
					end
				end
            end
            -- check if its a rep reward
			-- bgs
            if not isCraft and not isWBLoot and not isPvP then
                for k1,v1 in pairs(AtlasLoot_Data["AtlasLootBGItems"]) do
					for k2,v2 in pairs(AtlasLoot_Data["AtlasLootBGItems"][k1]) do
						if v2[1] == tonumber(tooltip.itemID) and string.find(v2[3], itemName, 1, true) then
							source = k1
							isRepReward = true
							if v2[5] then
								dropRate = v2[5]
								lastDropRate = dropRate
							else
								lastDropRate = nil
							end
						end
					end
				end
				-- factions
                for k1,v1 in pairs(AtlasLoot_Data["AtlasLootRepItems"]) do
					for k2,v2 in pairs(AtlasLoot_Data["AtlasLootRepItems"][k1]) do
						if v2[1] == tonumber(tooltip.itemID) and string.find(v2[3], itemName, 1, true) then
							source = k1
							isRepReward = true
							if v2[5] and source ~= "Darkmoon" and not string.find(source, "Cenarion",1,true) then
								dropRate = v2[5]
								lastDropRate = dropRate
							else
								lastDropRate = nil
							end
						end
					end
				end
            end
            -- check if its a set piece
			if not isCraft and not isWBLoot and not isPvP and not isRepReward then
				for k1,v1 in pairs(AtlasLoot_Data["AtlasLootSetItems"]) do
					for k2,v2 in pairs(AtlasLoot_Data["AtlasLootSetItems"][k1]) do
						if v2[1] == tonumber(tooltip.itemID) and string.find(v2[3], itemName, 1, true) then
							source = k1
							isSetPiece = true
							if (source == "SpiritofEskhandar" or
									source == "HakkariBlades" or
									source == "PrimalBlessing" or
									source == "ShardOfGods" or
									source == "DalRend" or
									source == "SpiderKiss" or
									source == "UnobMounts" or
									source == "Legendaries" or
									source == "Artifacts" or
									source == "ZGRings" or
									source == "Tabards" or string.find(source, "WorldEpics",1,true)) then
								source = nil
								isSetPiece = false
							end
							lastDropRate = nil
						end
					end
				end
			end
			-- check world events
			if not isCraft and not isWBLoot and not isPvP and not isRepReward and not isSetPiece then
				for k1,v1 in pairs(AtlasLoot_Data["AtlasLootWorldEvents"]) do
					for k2,v2 in pairs(AtlasLoot_Data["AtlasLootWorldEvents"][k1]) do
						if v2[1] == tonumber(tooltip.itemID) and string.find(v2[3], itemName, 1, true) then
							source = k1
							if source == "WintervielSnowball" and not (tonumber(tooltip.itemID) == 51249 or tonumber(tooltip.itemID) == 61089) then
								return
							end
							isWorldEvent = true
							if v2[5] then
								dropRate = v2[5]
								lastDropRate = dropRate
							else
								lastDropRate = nil
							end
						end
					end
				end
			end
            -- check if its a dungeon/raid loot
			if not isCraft and not isWBLoot and not isPvP and not isRepReward and not isWorldEvent and not isSetPiece then
				for k1,v1 in pairs(AtlasLoot_Data["AtlasLootItems"]) do
					for k2,v2 in pairs(AtlasLoot_Data["AtlasLootItems"][k1]) do
						if v2[1] ~= 0 then
							if v2[1] == tonumber(tooltip.itemID) and string.find(v2[3], itemName,1,true) then
								if k1 ~= "VanillaKeys" then
									source = k1
								end
								if v2[5] then
									dropRate = v2[5]
									lastDropRate = dropRate
								else
									lastDropRate = nil
								end
							end
						end
					end
				end
			end
			lastItemName = itemName
			lastItemID = tooltip.itemID
			if not source then
				lastSourceStr = nil
                return
			end
			
			for k,v in pairs(AtlasLoot_TableNames) do
				if k == source then
					sourceStr = AtlasLoot_TableNames[k][1]
					lastSourceStr = sourceStr
				end
			end
			
			if not sourceStr then
				return
			end

			if line2 and line2:GetText() then
				if dropRate then
					line2:SetText(GREY..sourceStr.." ("..dropRate..")|r\n"..line2:GetText())
				else
					line2:SetText(GREY..sourceStr.."|r\n"..line2:GetText())
				end
			else
				if dropRate then
					tooltip:AddLine(GREY..sourceStr.." ("..dropRate..")|r")
				else
					tooltip:AddLine(GREY..sourceStr.."|r")
				end
			end
		
		elseif itemName == lastItemName and tooltip.itemID == lastItemID then
			if lastSourceStr then
				if line2:GetText() then
					if lastDropRate then
						line2:SetText(GREY..lastSourceStr.." ("..lastDropRate..")|r\n"..line2:GetText())
					else
						line2:SetText(GREY..lastSourceStr.."|r\n"..line2:GetText())
					end
				else
					if lastDropRate then
						tooltip:AddLine(GREY..lastSourceStr.." ("..lastDropRate..")|r")
					else
						tooltip:AddLine(GREY..lastSourceStr.."|r")
					end
				end
			end
		end
	end
	tooltip:Show()
end

AtlasLootTip:SetScript("OnHide", function()
	GameTooltip.itemID = nil
	ItemRefTooltip.itemID = nil
end)

AtlasLootTip:SetScript("OnShow", function()
	AtlasLootTip.extendTooltip(GameTooltip, "GameTooltip")
end)
