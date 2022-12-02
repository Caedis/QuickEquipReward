
local QER = LibStub('AceAddon-3.0'):NewAddon('QuickEquipReward', 'AceEvent-3.0', 'AceConsole-3.0')

-- might be used later
QER.Retail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
QER.Classic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
QER.Wrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC

local waitingForItems = false
questRewards = {}
toEquip = {}

local function AreQuestRewardsReady()
	local totalrewards = GetNumQuestChoices()
	if totalrewards < 1 then return end

	local index
	for index=1, totalrewards do
		local link = GetQuestItemLink('choice', index)
		if not link then return end
	end

	return true
end

-- Dump: value=PawnIsItemIDAnUpgrade(11851)
-- [1]={
--   [1]={
--     ScaleName='\'MrRobot\':MONK1',
--     ExistingItemLink='item:72019:0:0:0:0:0:0:0:0:1450:0:75:0:0:0:0:0:0:0:0:0:0:0:0:0',
--     PercentUpgrade=1.999999999993,
--     LocalizedScaleName='Monk: Brewmaster'
--   }
-- },
-- [5]=false
local function AddPercentageUpgrade(i)
	local questReward = questRewards[i]
	if not questReward.equipLoc then
		return nil
	end

	local equipItemID = GetInventoryItemID('player', PawnGetSlotsForItemType(questReward.equipLoc))
	-- player has nothing in that slot
	if not equipItemID then return 100 end

	-- heirloom detection
	if C_Heirloom then
		if C_Heirloom.IsItemHeirloom(equipItemID) then
			local playerLevel = UnitLevel('player')
			local minLevel, maxLevel = select(9, C_Heirloom.GetHeirloomInfo(equipItemID))
			if playerLevel >= minLevel and playerLevel <= maxLevel then
				return nil
			end
		end
	end

	local pawnInfo = PawnGetItemData(questReward.itemLink)
	if not pawnInfo then return nil end
	local upgradeInfo = PawnIsItemAnUpgrade(pawnInfo)

	return upgradeInfo and upgradeInfo[1]['PercentUpgrade']
end

local function QUEST_COMPLETE()
	if not (_G.QuestFrameCompleteQuestButton and _G.QuestFrameCompleteQuestButton:IsVisible()) then return end

	local numQuestChoices = GetNumQuestChoices()

	if not AreQuestRewardsReady() then
		waitingForItems = true
		return
	end
	waitingForItems = false

	wipe(questRewards)
	for i=1,numQuestChoices do
		local itemLink = GetQuestItemLink('choice', i)
		local itemID, _, _, equipLoc = GetItemInfoInstant(itemLink)
		local sellPrice  = select(11, GetItemInfo(itemLink))
		questRewards[i] = {
			choiceIndex = i,
			itemLink = itemLink,
			itemID = itemID,
			equipLoc = equipLoc,
			sellPrice = sellPrice
		}

		questRewards[i].upgradePercent = AddPercentageUpgrade(i)
	end


	local function sortByUpgrade(a, b) return (a.upgradePercent or 0) > (b.upgradePercent or 0) end
	local function sortBySellPrice(a, b) return (a.sellPrice or 0) > (b.sellPrice or 0) end
	sort(questRewards, sortByUpgrade)


	if questRewards[1].upgradePercent then
		local highest = questRewards[1]
		QER:Print(strjoin('', 'Upgrade: ', highest.itemLink))
		toEquip[highest.itemID] = highest
		if IsShiftKeyDown() then return end
		QER:RegisterEvent('ITEM_PUSH')

		_G['QuestInfoRewardsFrameQuestInfoItem'..highest.choiceIndex]:Click()
	else
		sort(questRewards, sortBySellPrice)
		local highest = questRewards[1]
		QER:Print(strjoin('', 'Vendor: ', highest.itemLink, ' - ', GetMoneyString(highest.sellPrice)))
		if IsShiftKeyDown() then return end

		_G['QuestInfoRewardsFrameQuestInfoItem'..highest.choiceIndex]:Click()
	end


	_G.QuestRewardCompleteButton_OnClick()
end


local function QUEST_ITEM_UPDATE()
	local ready = AreQuestRewardsReady()
	if waitingForItems or ready then
		QUEST_COMPLETE()
	end
end

local function AutoEquip()
	for itemID, itemInfo in next, toEquip do
		C_Timer.After(1, function() QER:Print('Equipping: '..itemInfo.itemLink) EquipItemByName(itemID) end) -- 1 sec delay for reasons
		toEquip[itemID] = nil
	end
end

function QER:ITEM_PUSH()
	QER:UnregisterEvent('ITEM_PUSH')
	if InCombatLockdown() then
		QER:RegisterEvent('PLAYER_REGEN_ENABLED', AutoEquip)
		return
	end
	AutoEquip()
end


function QER:OnInitialize()
	QER:RegisterEvent('QUEST_ITEM_UPDATE', QUEST_ITEM_UPDATE)
	QER:RegisterEvent('QUEST_COMPLETE', QUEST_COMPLETE)
end
