
-- Mutilate -- spell recommendation for rogues. Originlly derived from FaceMauler.
--
-- How it works: getState() fills in a state table from fresh raw data (spell expirations,
-- expire times, energy levels, etc). Each spec's decide spell method does two things. It
-- decides the best spell given the state, and it walks the state forward at least a short time
-- as if that spell had just been cast. On each outermost update we start with the fresh state,
-- then repeatedly call the spec specific decide spell method to walk the state forward to discover
-- the immediate and future recommendations.
-- 

-- Sub: Not accounting for Deeper Strategem
-- Sub: Calling for finishers at 5 CP, not 6


Mutilate = {} -- Our addon-specific 'global' non-saved variables.
local ns = Mutilate -- A file private shorter namespace to reference them by.
local _ -- So we don't pollute the global _
local options -- Ref to our saved options. Will be set during load.

ns.addOnName = "Mutilate" -- To make cloning easier.

ns.lastUpdateTime = 0 -- For throttling OnUpdate() rate.
ns.spellsShowing = false
ns.lastSpell = ""

-- Energy costs. Not directly available through any API unfortunately.
ns.e = {}
ns.e.Vendetta = 0
ns.e.Garrote = 20
ns.e.Mutilate = 50
ns.e.Envenom  = 35
ns.e.Toxic_Blade = 20
ns.e.Rupture = 25
ns.e.Tricks_of_the_Trade = 0
ns.e.Vanish = 0
ns.e.Blindside = 30
ns.e.SymbolsOfDeath = 0
ns.e.Shadowstrike = 40
ns.e.Nightblade = 25
ns.e.Eviscerate = 35
ns.e.Backstab = 35
ns.e.Gloomblade = 35
ns.e.Crimson_Vial = 30
ns.e.Ambush = 60
ns.e.Dispatch = 35
ns.e.Sinister_Strike = 45
ns.e.Slice_and_Dice = 25
ns.e.Pistol_Shot = 40
ns.e.Ghostly_Strike = 30
ns.e.Kingsbane = 35
ns.e.Between_the_Eyes = 35
--ns.e.Trinket_1 = 0

ns.id = {}
ns.id.Assassination = 259
ns.id.Outlaw = 260
ns.id.Subtlety = 261
ns.id.Kingsbane = 192759
ns.id.Curse_of_the_Dreadblades = 202665
ns.id.Goremaws_Bite = 209782
--ns.id.Trinket_1 = 151190	--make this 0 if you have no useable trinket, otherwise find its ID
ns.id.Toxic_Blade = 245388

ns.open = {}
ns.open.active = 0
ns.open.waiting = 1
ns.open.nextMove = ""





-- Return a localised spell name.
function ns.GetSpellNameById(spellId)
	local spellName, _, _, _, _, _, _, _, _ = GetSpellInfo(spellId)
	return spellName
end

-- Localized names of spells we are interested in, indexed by english name with underbars. We need
-- to use the local name (or id) in calls refering to the spell. We chose to use local name rather
-- than id because debugging is easier and some APIs need it.
ns.n = {}

ns.n.Vendetta            = ns.GetSpellNameById(79140)
ns.n.Garrote             = ns.GetSpellNameById(703)
ns.n.Mutilate            = ns.GetSpellNameById(1329)
ns.n.Envenom             = ns.GetSpellNameById(32645)
ns.n.Rupture             = ns.GetSpellNameById(1943)
ns.n.Tricks_of_the_Trade = ns.GetSpellNameById(57934)
ns.n.Vanish              = ns.GetSpellNameById(1856)
ns.n.Kick           	 = ns.GetSpellNameById(1766)
ns.n.Shiv 				 = ns.GetSpellNameById(5938)
ns.n.Cloak_of_Shadows 	 = ns.GetSpellNameById(31224)
ns.n.Blindside 		 	= ns.GetSpellNameById(111240)
ns.n.Exsanguinate		 = ns.GetSpellNameById(200806) 
ns.n.Symbols_of_Death	 = ns.GetSpellNameById(212283)
ns.n.Shadow_Blades  	 = ns.GetSpellNameById(121471)
ns.n.Shadowstrike  	 	 = ns.GetSpellNameById(185438)
ns.n.Nightblade  	 	 = ns.GetSpellNameById(195452)
ns.n.Shadow_Dance  	 	 = ns.GetSpellNameById(185313)
ns.n.Backstab  	 	 	 = ns.GetSpellNameById(53)
ns.n.Gloomblade  	 	 = ns.GetSpellNameById(200758)
ns.n.Stealth  	 		 = ns.GetSpellNameById(1784)
ns.n.Eviscerate  	 	 = ns.GetSpellNameById(196819) 
ns.n.Subterfuge          = ns.GetSpellNameById(108208)
ns.n.Crimson_Vial        = ns.GetSpellNameById(185311)
ns.n.Marked_for_Death    = ns.GetSpellNameById(137619)
ns.n.Sinister_Strike		 = ns.GetSpellNameById(193315)
ns.n.Opportunity		 = ns.GetSpellNameById(195627)
ns.n.Dispatch		 = ns.GetSpellNameById(2098)
ns.n.Roll_the_Bones		 = ns.GetSpellNameById(193316)
ns.n.True_Bearing		 = ns.GetSpellNameById(193359)
ns.n.Adrenaline_Rush	 = ns.GetSpellNameById(13750)
ns.n.Pistol_Shot	     = ns.GetSpellNameById(185763)
ns.n.Ambush	             = ns.GetSpellNameById(8676)
ns.n.Ruthless_Precision  = ns.GetSpellNameById(193357)
ns.n.Skull_and_Crossbones = ns.GetSpellNameById(199603)
ns.n.Grand_Melee		 = ns.GetSpellNameById(193358)
ns.n.Broadsides		     = ns.GetSpellNameById(193356)
ns.n.Buried_Treasure	 = ns.GetSpellNameById(199600)
ns.n.Slice_and_Dice	     = ns.GetSpellNameById(5171)
ns.n.Killing_Spree	     = ns.GetSpellNameById(51690)
ns.n.Quick_Draw	     	 = ns.GetSpellNameById(196938)
ns.n.Venon_Rush	     	 = ns.GetSpellNameById(152152)
ns.n.Ghostly_Strike	     = ns.GetSpellNameById(196937)
ns.n.Between_the_Eyes	 = ns.GetSpellNameById(199804)
ns.n.Kingsbane  	     = ns.GetSpellNameById(ns.id.Kingsbane)
ns.n.Toxic_Blade         = ns.GetSpellNameById(ns.id.Toxic_Blade)
ns.n.Curse_of_the_Dreadblades = ns.GetSpellNameById(ns.id.Curse_of_the_Dreadblades)
ns.n.Goremaws_Bite 		 = ns.GetSpellNameById(ns.id.Goremaws_Bite) -- Pronounce: Goremore's Bite

--ns.n.Trinket_1	 = ns.GetSpellNameById(246461) -- set to 0 if no trinket, otherwise find the ID of the spell (not trinket id)


-- Our sneaky frame to watch for events ... looks up ns.events[] for a function the same name
-- as the event.  Passes all args.
ns.eventFrame = CreateFrame("Frame")
ns.eventFrame:SetScript("OnEvent", function(this, event, ...) ns.events[event](...) end)

ns.eventFrame:RegisterEvent("ADDON_LOADED")
ns.eventFrame:RegisterEvent("PLAYER_ALIVE")
ns.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
ns.eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
ns.eventFrame:RegisterEvent("SPELLS_CHANGED")


-- Define our Event Handlers here
ns.events = {}

function ns.CheckSpec()
	local currentSpec = GetSpecialization()
	local currentSpecID = currentSpec and select(1, GetSpecializationInfo(currentSpec)) or 0
	if currentSpecID == ns.id.Assassination then
		ns.spec = "Assassination"
		ns.displayFrame:Show() 
	elseif currentSpecID == ns.id.Outlaw then
		ns.spec = "Outlaw"
		ns.displayFrame:Show() 
	elseif currentSpecID == ns.id.Subtlety then
		ns.spec = "Subtlety"
		ns.displayFrame:Show() 
	else
		ns.displayFrame:Hide() 
	end 	
end

function ns.HasTalent(tier, col)
	local group = GetActiveSpecGroup()
	local _, _, _, selected, _ = GetTalentInfo(tier, col, group, nil, "player")
	return selected
end

function ns.events.PLAYER_TALENT_UPDATE()
	ns.CheckSpec()

	if ns.spec == "Assassination" then
		ns.hasBlindsideTalent = ns.HasTalent(1, 3) 
		ns.hasSubterfugeTalent = ns.HasTalent(2, 2)
		ns.hasDeeperStrategemTalent = ns.HasTalent(3, 2)
		ns.hasExsanguinateTalent = ns.HasTalent(6, 3)
		ns.hasVenomRushTalent = ns.HasTalent(7, 1)
		ns.hasMarkedForDeathTalent = ns.HasTalent(3,3)
	elseif ns.spec == "Outlaw" then
		ns.hasGhostlyStrikeTalent = ns.HasTalent(1, 3)
		ns.hasQuickDrawTalent = ns.HasTalent(1, 2)
		ns.hasDeeperStrategemTalent = ns.HasTalent(3, 2)
		ns.hasKillingSpreeTalent = ns.HasTalent(7, 3)
		ns.hasSliceAndDiceTalent = ns.HasTalent(6, 3)
		ns.hasMarkedForDeathTalent = ns.HasTalent(6 ,3)
	elseif ns.spec == "Subtlety" then
		ns.hasGloombladeTalent = ns.HasTalent(1, 3)
		ns.hasSubterfugeTalent = ns.HasTalent(2, 2)
		ns.hasDeeperStrategemTalent = ns.HasTalent(3, 2)
		ns.hasEnvelopingShadowTalent = ns.HasTalent(6 ,3)
		ns.hasMasterOfShadowsTalent = ns.HasTalent(7 ,1)
		ns.hasMarkedForDeathTalent = ns.HasTalent(3 ,3)
	end

	ns.maxEnergy = UnitPowerMax("player");
	ns.globalCooldown = 1 -- Also updated whenever we see it.

end

function ns.events.PLAYER_ALIVE()

	ns.eventFrame:UnregisterEvent("PLAYER_ALIVE")
end




function ns.events.ADDON_LOADED(addon)

	if addon ~= ns.addOnName then 
		return 
	end

	local _,playerClass = UnitClass("player")
	if playerClass ~= "ROGUE" then
		ns.eventFrame:UnregisterEvent("PLAYER_ALIVE")
		ns.eventFrame:UnregisterEvent("ADDON_LOADED")
		ns.eventFrame:UnregisterEvent("PLAYER_LOGIN")
		ns.eventFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
		ns.eventFrame:UnregisterEvent("PLAYER_TALENT_UPDATE")
		ns.eventFrame:UnregisterEvent("SPELLS_CHANGED")
		return 
	end
	
	-- Default saved variables
	if not Mutilatedb then
		Mutilatedb = {} -- fresh start
	end
	options = Mutilatedb -- Generic file-local short name.

	if not options.scale then options.scale = 1 end
	if options.locked == nil then options.locked = false end
	if not options.x then options.x = 100 end
	if not options.y then options.y = 100 end
	if not options.SuggestVanish then options.SuggestVanish = false end
	if not options.SuggestVendetta then options.SuggestVendetta = false end
	if not options.SliceAndDiceTimer then options.SliceAndDiceTimer = 1.0 end
	if not options.VoiceLeadTime then options.VoiceLeadTime = 0.5 end
	if not options.RuptureTimer then options.RuptureTimer = 2.0 end
	if not options.RuptureClipTimer then options.RuptureClipTimer = 0.0 end
	if not options.PoolEnergyThreshold then options.PoolEnergyThreshold = 90 end
	if not options.RuptureCp then options.RuptureCp = 1 end
	if not options.EnvenomCp then options.EnvenomCp = 4 end
	if not options.PlayerHealthThreshold then options.PlayerHealthThreshold = 50 end
	if not options.EnvenomTimer then options.EnvenomTimer = 0 end
	if not options.BackstabEnvenomCp then options.BackstabEnvenomCp = 5 end
	if not options.SuggestGarroteAsStealthOpener then options.SuggestGarroteAsStealthOpener = true end
	if options.SuggestCloakOfShadows == nil then options.SuggestCloakOfShadows = true end
	if not options.MinDebuffDurationForCofs then options.MinDebuffDurationForCofs = 10 end
	if options.VoicePrompts == nil then options.VoicePrompts = false end
	if not options.ConsoleTrace == nil then options.Trace = false end
	if not options.PretendInGroup == nil then options.PretendInGroup = false end
	if not options.ExsanguinateTrigger then options.ExsanguinateTrigger = 30 end
	if not options.SoundChannel then options.SoundChannel = "No sound" end


	-- Create GUI
	ns.CreateGUI()
	ns.displayFrame:SetScale(options.scale)


	-- Create Options Frame
	ns.CreateOptionFrame()
	if options.locked then
		ns.displayFrame:SetScript("OnMouseDown", nil)
		ns.displayFrame:SetScript("OnMouseUp", nil)
		ns.displayFrame:SetScript("OnDragStop", nil)
		ns.displayFrame:SetBackdropColor(0, 0, 0, 0)
		ns.displayFrame:EnableMouse(false)
	else
		ns.displayFrame:SetScript("OnMouseDown", function(self) self:StartMoving() end)
		ns.displayFrame:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
		ns.displayFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
		ns.displayFrame:SetBackdropColor(0, 0, 0, .4)
		ns.displayFrame:EnableMouse(true)
	end

	-- Register for Slash Commands
	SlashCmdList["Mutilate"] = ns.Options -- Defined below.
	SLASH_Mutilate1 = "/Mutilate"
	SLASH_Mutilate2 = "/mut"
	

	-- Register for Function Events
	ns.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	ns.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

	ns.CheckSpec()

	ns.mainSpellBlankedTime = GetTime();


	-- This is probably normally caled by framework, but just be be sure. Applies spec and talent based settings.
	ns.events.PLAYER_TALENT_UPDATE()

	ns.selfCheck = false
	
end

-- Show or hide the spell textures.
function ns.ShowSpellsIf(yes)
	if ns.spellsShowing == yes then
		return
	end
	if not yes then
		ns.displayFrameRecommend:Hide()
		ns.displayFrameC1:Hide()
		ns.displayFrameA1:Hide()
		ns.displayFrameB1:Hide()
		ns.displayFrameB2:Hide()
		ns.displayFrameA2:Hide()
		ns.displayFrameD1:Hide()
		ns.displayFrameC2:Hide()
		ns.displayFrameD2:Hide()
		ns.leftText:SetText("")
		ns.rightText:SetText("")
		ns.saidSpell = nil
		ns.saidKick = false
	else
		ns.displayFrameRecommend:Show()
		ns.displayFrameC1:Show()
		ns.displayFrameA1:Show()
		ns.displayFrameB1:Show()
		ns.displayFrameB2:Show()
		ns.displayFrameA2:Show()
		ns.displayFrameD1:Show()
		ns.displayFrameC2:Show()
		ns.displayFrameD2:Show()
		ns.DecideSpells()
	end
	ns.spellsShowing = yes
end


function ns.events.COMBAT_LOG_EVENT_UNFILTERED(...)

	local timestamp, eventType, hideCaster, sourceGUID, srcName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, extraArg1, spellName, extraArg3, extraArg4, extraArg5, extraArg6, extraArg7, extraArg8, extraArg9, extraArg10 = CombatLogGetCurrentEventInfo()


	ns.ShowSpellsIf(UnitName("target") ~= nil
		and UnitCanAttack("player", "target")
		and UnitHealth("target") > 0)


	if ns.spec == "Assassination" then
	  	if UnitName("player") == srcName then
			if (eventType=="SPELL_DAMAGE") or (eventType=="SPELL_ENERGIZE") or (eventType == "SPELL_CAST_SUCCESS") then
		  		if (spellName == "Mutilate") or (spellName == "Garrote") or (spellName == "Rupture") or (spellName == "Vendetta") or (spellName == "Toxic Blade") or (spellName == "Kingsbane") or (spellName == "Vanish") or (spellName == "Envenom") then 
		  			ns.lastSpell = spellName
		  		end
		  	end

	  	end
  end

end

function ns.events.PLAYER_TARGET_CHANGED(...)
	
	ns.ShowSpellsIf(UnitName("target") ~= nil
		and UnitCanAttack("player", "target")
	 	and UnitHealth("target") > 0)

end

function ns.events.SPELLS_CHANGED(...)

	if not ns.CheckSpec() then
		return
	end
end

-- End Event Handlers

-- Utility used to establish the frame and texture of one icon slot.
function ns.CreateFrameAndTextureOnGrid(displayFrameName, textureName, tlx, tly, width, height)
  local df = CreateFrame("Frame", "$parent_"..displayFrameName, ns.displayFrame)
  ns[displayFrameName] = df
  df:SetWidth(width)
  df:SetHeight(height)
  df:SetPoint("TOPLEFT", tlx, tly)
  local t = df:CreateTexture(nil, "BACKGROUND")
  ns[textureName] = t
  t:SetTexture(nil)
  t:SetAllPoints(df)
  t:SetAlpha(.8)
  df.texture = t -- Necessary?
  return t
end

function ns.CreateGUI()

	local gdf = CreateFrame("Frame", "MutilateFrame", UIParent)
	ns.displayFrame = gdf
	gdf:SetFrameStrata("BACKGROUND")
	gdf:SetWidth(350)
	gdf:SetHeight(107)
	gdf:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 32})
	gdf:SetBackdropColor(0, 0, 0, .4)
	gdf:EnableMouse(true)
	gdf:SetMovable(true)
	gdf:SetClampedToScreen(true)
	gdf:SetScript("OnMouseDown", function(self) self:StartMoving() end)
	gdf:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
	gdf:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	gdf:SetPoint("CENTER", -200, -200)

    -- Frames are named like a spreadsheet around the central recommenndation. So C1 in the next spell.
    -- A1 B1   REC   C1 D1
    -- A2 B2   OMM   C2 D2
    --left text right text
	ns.CreateFrameAndTextureOnGrid("displayFrameRecommend", "textureRecommend", 140, -10, 70, 70)
	ns.CreateFrameAndTextureOnGrid("displayFrameA1", "textureA1", 0, 0, 45, 45)
	ns.CreateFrameAndTextureOnGrid("displayFrameA2", "textureA2", 0, -50, 45, 45)
	ns.CreateFrameAndTextureOnGrid("displayFrameB1", "textureB1", 50, 0, 45, 45)
	ns.CreateFrameAndTextureOnGrid("displayFrameB2", "textureB2", 50, -50, 45, 45)
	ns.CreateFrameAndTextureOnGrid("displayFrameC1", "textureC1", 250, 0, 45, 45)
	ns.CreateFrameAndTextureOnGrid("displayFrameC2", "textureC2", 250, -50, 45, 45)
	ns.CreateFrameAndTextureOnGrid("displayFrameD1", "textureD1", 300, 0, 45, 45)
	ns.CreateFrameAndTextureOnGrid("displayFrameD2", "textureD2", 300, -50, 45, 45)
	

	ns.c1CooldownFrame = CreateFrame("Cooldown", "$parent_c1CooldownFrame", ns.displayFrameC1, "CooldownFrameTemplate")
	ns.spellCooldownFrame = CreateFrame("Cooldown", "$parent_spellCooldownFrame", ns.displayFrameRecommend, "CooldownFrameTemplate")

	ns.leftText = gdf:CreateFontString("kickName", "OVERLAY", "GameFontNormal")
	ns.leftText:SetText("")
	ns.leftText:SetPoint("TOPLEFT", 0, -95)
	ns.rightText = gdf:CreateFontString("cofsName", "OVERLAY", "GameFontNormal")
	ns.rightText:SetJustifyH("RIGHT")
	ns.rightText:SetText("")
	ns.rightText:SetPoint("TOPRIGHT", 0, -95)

	gdf:SetScript("OnUpdate", function(this, elapsed) ns.OnUpdate(elapsed) end)
end

function ns.OnUpdate(elapsed)
	ns.DecideSpells() -- Decide spells has rate throttling.
end

-- Return when debuff on the target will expire. 0 or some value now or less if it has already.
function ns.getDebuffExpiration(spellName)
	local expirationTime = 0
	for i=1,40 do
		local name, _, _, _, _, thisExpirationTime, isMine, _ = UnitDebuff("target", i, PLAYER)
		if name == spellName then
			expirationTime = thisExpirationTime
			break;
		end
	end

	return expirationTime
	
end

-- Return when debuff on the player will expire. 0 or some value now or less if it has already.
function ns.getMyDebuffExpiration(spellName)
	local expirationTime = 0
	for i=1,40 do
		local name, _, _, _, _, _, thisExpirationTime, isMine, _ = UnitDebuff("player", i, PLAYER)
		if name == spellName then
			expirationTime = thisExpirationTime
			break;
		end
	end

	return expirationTime

end

-- Return when this buff on the player will expire. 0 or some value now or less if it has already.
function ns.getBuffExpiration(spellName)
	local thisExpirationTime = 0
	for i=1,40 do
		--local name, _, _, _, _, _, thisExpirationTime, isMine, _ = UnitBuff("player", i, PLAYER)
		local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, 
  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff("player", i, PLAYER)


		if name == spellName then
			thisExpirationTime = expirationTime
			break;
		end
	end

	return thisExpirationTime

end

-- Return when this spell will be available for casting with respect to its cooldown.
-- Returns 0 if possible for easier debug.
function ns.getReadyTime(spellName, s)
	local start, duration, enabled = GetSpellCooldown(spellName);
	if duration ~= nil and start + duration > s.now + 0.01 then 
		return start + duration
	end
	
	return 0
end

function ns.getItemReadyTime(itemID, s)
	local start, duration, enabled = GetItemCooldown(itemID);
	if duration ~= nil and start + duration > s.now + 0.01 then 
		return start + duration
	end
	return 0
end

-- Return a table with all the interesting facts about the current state. All times are absolute.
-- Buffs and debuffs are active if their expiration is in the future. Assumes target exists and
-- is unfriendly. Returns nil if we are in first few hundred milliseconds of the start of
-- global cooldown, in which state is often confused. In this situation, caller should assume
-- a spell has been cast (i.e. clear the recommendation) and hold predition as is.
function ns.GetState(now)

	local globalCoolDownExpiration = now
	local start, duration, enabled = GetSpellCooldown(61304); -- The speical global cooldown spell ID.
	if duration ~= nil and duration ~= 0 then
		globalCoolDownExpiration = max(now, start + duration)
		if now - start < 0.25 then 
			return nil
		end
		-- Global cooldown can vary and it is hard to find our what it is. Updaete it every time
		-- we see it.
		ns.globalCooldown = duration
	end
	ns.knowsKingsbane = IsSpellKnown(ns.id.Kingsbane, false)
	ns.knowsCurse_of_the_DreadBlades = IsSpellKnown(ns.id.Curse_of_the_Dreadblades, false)
	ns.knowsGoremaws_Bite = IsSpellKnown(ns.id.Goremaws_Bite, false)

	local s = {}
	s.now = now
	s.globalCoolDownExpiration = globalCoolDownExpiration

	s.energy = UnitPower("player")
	s.comboPoints = GetComboPoints("player", "target")
	s.isInGroup = IsInGroup() or options.PretendInGroup

	s.removeableName = ""
	s.longDurationDebuffs = false
	-- Scan player's debuffs for things Cloak of Shadows could remove.
	for i = 1, 40 do -- There are 1..40 aura slots.
		--local name, _, _, count, debuffType, _, expirationTime, unitCaster, canStealOrPurge, _, _, _, _ = UnitDebuff("player", i)
		--local name, _, _, count, _, expirationTime, unitCaster, canStealOrPurge, _ = UnitDebuff("target", i, PLAYER)
		local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitDebuff("target", i, PLAYER)


		if name == nil then
			break 
		end
		if expirationTime > s.now then
			local duration = math.floor(expirationTime - s.now)
			if duration < 60 * 10 then -- Don't show times > 10m
				s.removeableName = s.removeableName..""..duration.."s "
			end
			if duration > options.MinDebuffDurationForCofs then
				s.longDurationDebuffs = true
			end
		else
			s.longDurationDebuffs = true
		end
		if count > 1 then
			s.removeableName = s.removeableName..count.."*"
		end
		s.removeableName = s.removeableName..name.."\n"
	end

	-- See if there is something we can kick.
	s.interruptibleName = nil
	local name, _, displayName, _, _, endTime, _, notInterruptible = UnitChannelInfo("target")
	if name ~= nil and not notInterruptible then
		s.interruptibleName = displayName
	end
	local name, _, displayName, _, _, endTime, _, _, notInterruptible = UnitCastingInfo("target")
	if name ~= nil and not notInterruptible then
		s.interruptibleName = displayName
	end

	-- When our debuffs on the target will expire. If <= s.now, they are not up.
	s.Garrote_Expiration = ns.getDebuffExpiration(ns.n.Garrote)
	s.Rupture_Expiration = ns.getDebuffExpiration(ns.n.Rupture)
	s.Envenom_Expiration = ns.getDebuffExpiration(ns.n.Envenom)
	s.Nightblade_Expiration = ns.getDebuffExpiration(ns.n.Nightblade)
	s.Ghostly_Strike_Expiration = ns.getDebuffExpiration(ns.n.Ghostly_Strike)

	-- When our buffs will expire. If <= s.now, they are not up.
	s.Symbols_of_Death_Expiration = ns.getBuffExpiration(ns.n.Symbols_of_Death)
	s.Shadow_Blades_Expiration = ns.getBuffExpiration(ns.n.Shadow_Blades)
	s.Shadow_Dance_Expiration = ns.getBuffExpiration(ns.n.Shadow_Dance)
	s.Subterfuge_Expiration = ns.getBuffExpiration(ns.n.Subterfuge)

	if ns.spec == "Outlaw" then
		s.Opportunity_Expiration = ns.getBuffExpiration(ns.n.Opportunity)
		s.Slice_and_Dice_Expiration = ns.getBuffExpiration(ns.n.Slice_and_Dice)
		s.Adrenaline_Rush_Expiration = ns.getBuffExpiration(ns.n.Adrenaline_Rush)

		s.True_Bearing_Expiration = ns.getBuffExpiration(ns.n.True_Bearing)
		s.Ruthless_Precision_Expiration = ns.getBuffExpiration(ns.n.Ruthless_Precision)
		s.Skull_and_Crossbones_Expiration = ns.getBuffExpiration(ns.n.Skull_and_Crossbones)
		s.Grand_Melee_Expiration = ns.getBuffExpiration(ns.n.Grand_Melee)
		s.Broadsides_Expiration = ns.getBuffExpiration(ns.n.Broadsides)
		s.Buried_Treasure_Expiration = ns.getBuffExpiration(ns.n.Buried_Treasure)
		s.Curse_of_the_Dreadblades_Expiration = ns.getMyDebuffExpiration(ns.n.Curse_of_the_Dreadblades)
		s.Curse_of_the_Dreadblades_ReadyTime = ns.getReadyTime(ns.n.Curse_of_the_Dreadblades, s)
		s.Between_the_Eyes_ReadyTime = ns.getReadyTime(ns.n.Between_the_Eyes, s)
	elseif ns.spec == "Assassination" then
		s.Kingsbane_ReadyTime = ns.getReadyTime(ns.n.Kingsbane, s)
		s.ToxicBlade_ReadyTime = ns.getReadyTime(ns.n.Toxic_Blade, s)
		s.Blindside_Expiration = ns.getBuffExpiration(ns.n.Blindside)
		s.Vendetta_Expiration = ns.getBuffExpiration(ns.n.Vendetta)
	elseif ns.spec == "Subtlety" then
		s.Goremaws_Bite_ReadyTime = ns.getReadyTime(ns.n.Goremaws_Bite, s)
	end

	-- Cooldowns. Any value <= s.now indicates they are cooled down and ready to cast (given
	-- whatever other constraints apply).
	s.vendettaReadyTime = ns.getReadyTime(ns.n.Vendetta, s)
	s.tricksOfTheTradeReadyTime = ns.getReadyTime(ns.n.Tricks_of_the_Trade, s)
	s.vanishReadyTime = ns.getReadyTime(ns.n.Vanish, s)
	s.kickReadyTime = ns.getReadyTime(ns.n.Kick, s)
	s.cofsReadyTime = ns.getReadyTime(ns.n.Cloak_of_Shadows, s)
	s.garroteReadyTime = ns.getReadyTime(ns.n.Garrote, s)
	
	
	s.exsanguinateReadyTime = ns.getReadyTime(ns.n.Exsanguinate, s)
	s.shadowDanceReadyTime = ns.getReadyTime(ns.n.Shadow_Dance, s)
	s.symbolsOfDeathReadyTime = ns.getReadyTime(ns.n.Symbols_of_Death, s)
	s.stealthReadyTime = ns.getReadyTime(ns.n.Stealth, s)
	s.shadowBladesReadyTime = ns.getReadyTime(ns.n.Shadow_Blades, s)
	s.crimsonVialReadyTime = ns.getReadyTime(ns.n.Crimson_Vial, s)
	s.markedForDeathReadyTime = ns.getReadyTime(ns.n.Marked_for_Death, s)
	s.adrenalineRushReadyTime = ns.getReadyTime(ns.n.Adrenaline_Rush, s)
	s.ambushReadyTime = ns.getReadyTime(ns.n.Ambush, s)
	
--	s.trinket1ReadyTime = ns.getItemReadyTime(ns.id.Trinket_1, s)

	
	s.shadowDanceChargesAvail, _, _, _ = GetSpellCharges(ns.n.Shadow_Dance)

	local iAmStealthed = false
	for i=1,40 do
		local myAuras name,_,_,_,_,_,_,st=UnitAura("player",i)
		if name == "Stealth" then
			iAmStealthed = true
			break
		end
	end
	s.playerIsStealthed = iAmStealthed

	s.inCombat = UnitAffectingCombat("player")

	
	s.playerHealthFraction = UnitHealth("player") / UnitHealthMax("player")

	_, s.combatEnergyRegenPerSec = GetPowerRegen()

	return s
end

-- Return a one-line state summary for debug output. Scrubs uninteresting values and makes time
-- relative to now.
function ns.StateSummary(s)
	local summary = ""
	for k, v in pairs(s) do
		if v ~= 0 and v ~= false and v ~= "" and k ~= "now" then
			if string.find(k, "ReadyTime") or string.find(k, "Expiration") then
				v = v - s.now
				if v <= 0 then
					v = nil
				else
					v = string.format("%.2f", v)
				end
			end
			if v ~= "0.00" and v ~= nil then
				summary = summary .. " " .. k .. "=" .. tostring(v)
			end
		end
	end
	return summary
end

-- Determine a recommened spell, if any, from the given state. In the process, advance the state to
-- some future time where something might be different. Always advances the time of the state by at
-- least a little.
-- Returned spell is our internal spell name (i.e. English with underbars).
function ns.GetSpellFromState(s, debugStr)
	if not s.inCombat and UnitAffectingCombat("player") then
		s.inCombat = UnitAffectingCombat("player")
	end
	if false then
		return ns.GeSpellFromStateScreenshot(s)
	elseif ns.spec == "Assassination" and ns.open.active == 0 then
		return ns.GeSpellFromStateAssassination(s)
	elseif ns.spec == "Assassination" and ns.open.active == 1 then

		return ns.GeOpenerSpellFromStateAssassination(s)
	elseif ns.spec == "Outlaw" then
		return ns.GeSpellFromStateOutlaw(s)
	elseif ns.spec == "Subtlety" then
		return ns.GeSpellFromStateSubtlety(s)
	end
end

function ns.GeSpellFromStateScreenshot(s)
	s.now = s.now + 1
	spell = "Mutilate"
	if not s.doneOne then
		s.doneOne = true
	else
		spell = "Envenom"
	end
	return spell, true, ns.n.Vendetta, true, true,
		"Cast/channel you can kick", ns.n.Cloak_of_Shadows,
		"Debuff CofS will remove", ns.n.Marked_for_Death
end


function ns.GeSpellFromStateAssassination(s)
	local spell = nil;
	local oldNow = s.now
	-- Combo spend poiont for Assassination is one less than max because Mutilate gives 2.
	local maxComboPtsToSpend = 4
	local maxCombos = 5
	local markedForDeathGrant = 5
	
		
	if ns.hasDeeperStrategemTalent then
		maxComboPtsToSpend = 5
		maxCombos = 6
		markedForDeathGrant = 6
	end

	local stealthy = s.playerIsStealthed or s.Subterfuge_Expiration > s.now
		
	
	local vanishOk = s.vanishReadyTime <= s.now and s.isInGroup
	
	if s.globalCoolDownExpiration > s.now then  -- Global Cooldown - can't do anything
		s.now = s.globalCoolDownExpiration

	elseif s.comboPoints >= maxComboPtsToSpend and vanishOk and s.Vendetta_Expiration > 0 then
		spell = "Vanish"
		s.vanishReadyTime = s.now + 120

	elseif s.energy >= ns.e.Crimson_Vial 
		and s.crimsonVialReadyTime <= s.now
		and s.playerHealthFraction < options.PlayerHealthThreshold / 100
		then

		spell = "Crimson_Vial"
		s.crimsonVialReadyTime = s.now + 30
		s.energy = s.energy - ns.e.Crimson_Vial

-- 10/31 added a 2 second check on Rupture expiring
	

	elseif not s.playerIsStealthed and not s.inCombat and s.stealthReadyTime < s.now then

		-- Always open from stealth
		spell = "Stealth"
		s.playerIsStealthed = true
		s.stealthReadyTime = s.now + 2

	elseif ns.hasExsanguinateTalent
		and s.exsanguinateReadyTime <= s.now then
		--todo: Now that Hemo is gone, double check this calc

		spell = "Exsanguinate"
		s.Rupture_Expiration = s.now + max(0, s.Rupture_Expiration - s.now) / 2
		s.Garrote_Expiration = s.now + max(0, s.Garrote_Expiration - s.now) / 2
		s.exsanguinateReadyTime = s.now + 45
		ns.enterCombat(s)

	elseif s.Garrote_Expiration < s.now + 18 / 4 -- Pandemic
			and s.inCombat
			and s.garroteReadyTime <= s.now then

			-- No garrote bleed active and need combo points.
			spell = "Garrote"
			s.comboPoints = max(maxCombos, s.comboPoints + 1)
			s.energy = s.energy - ns.e.Garrote 
			s.Garrote_Expiration =  ns.pandemicExpiration(s, s.Garrote_Expiration, 18)
			ns.SpendCombos(s)
			if not stealthy or not ns.hasSubterfugeTalent then
				s.garroteReadyTime = s.now + 15
			end
			ns.enterCombat(s)

	elseif s.playerIsStealthed and not s.inCombat then
		spell = "Garrote"
		--s.comboPoints = max(maxCombos, s.comboPoints + 1)
		s.energy = s.energy - ns.e.Garrote 
		--s.Garrote_Expiration =  ns.pandemicExpiration(s, s.Garrote_Expiration, 18)
		--ns.SpendCombos(s)
		if not stealthy or not ns.hasSubterfugeTalent then
			s.garroteReadyTime = s.now + 15
		end
		ns.open.active = 1
		--ns.leftText:SetText("|cffFFffFF".."Standard Opener")
		ns.lastSpell = ""
		ns.open.nextMove = "Garrote1"
		ns.enterCombat(s)

-- 10/31 moved Kingsbane up, pre-toxic
	elseif ns.knowsKingsbane
		and s.energy >= ns.e.Kingsbane
		and s.Kingsbane_ReadyTime <= s.now
		then

		spell = "Kingsbane"
		s.energy = s.energy - ns.e.Kingsbane 
		s.Kingsbane_ReadyTime = s.now + 45
		s.comboPoints = min(maxCombos, s.comboPoints + 1)
		ns.enterCombat(s)

	elseif  s.inCombat and s.ToxicBlade_ReadyTime <= s.now and s.comboPoints < maxCombos then
		spell = "Toxic_Blade"
		s.energy = s.energy - ns.e.Toxic_Blade 
		s.ToxicBlade_ReadyTime = s.now + 25
		if ns.open.active == 0 then
			ns.leftText:SetText("")
		end
		s.comboPoints = min(maxCombos, s.comboPoints + 1)
		ns.enterCombat(s)

	

	elseif ns.hasMarkedForDeathTalent
		and maxCombos - s.comboPoints >= markedForDeathGrant
		and s.markedForDeathReadyTime <= s.now
		then

		-- Cast Marked for Death whenever off cooldown and we will get all 6 from it.
		spell = "Marked_for_Death"
		s.markedForDeathReadyTime = s.now + 60
		s.comboPoints = min(maxCombos, s.comboPoints + markedForDeathGrant)
	
-- 10/31 added back in
	elseif s.vendettaReadyTime <= s.now and s.energy <= 80 then
		spell = "Vendetta"
		ns.enterCombat(s)

	elseif s.energy >= ns.e.Rupture 
		and ((s.comboPoints >= 4	and s.Rupture_Expiration < s.now + 7) 
		or (s.comboPoints > 0 and s.Rupture_Expiration < s.now))
		then

		-- Rupture expiration is subject to Pandemic (i.e. new buff time adds to existing if close to
		-- end).  If we have even one combo point and we are within the renew period, renew. This
		-- also covers the case when it is not up a all. Note the pandemic idea of the spell duration
		-- seems to be based on the current combos, not it was case with.
		spell = "Rupture"
		local comboSpend = ns.SpendCombos(s)
		s.Rupture_Expiration = ns.pandemicExpiration(s, s.Rupture_Expiration, (comboSpend + 1) * 4)
		s.energy = s.energy - ns.e.Rupture 
		ns.enterCombat(s)

	elseif s.energy >= ns.e.Envenom
		and s.energy >= ns.maxEnergy * 0.95
		and s.comboPoints > 0 then

		-- If we are at max energy and we have even one combo point, evenom, because its better than
		-- wasting energy.
		spell = "Envenom"
		s.energy = s.energy - ns.e.Envenom 
		s.Envenom_Expiration = s.now + s.comboPoints + 1
		ns.SpendCombos(s)
		ns.enterCombat(s)

	elseif s.energy >= ns.e.Envenom  and s.comboPoints >= maxComboPtsToSpend -1 then

		-- Dump this full load of combo points into an envemom.
		spell = "Envenom"
		s.energy = s.energy - ns.e.Envenom 
		s.Envenom_Expiration = s.now + s.comboPoints + 1
		ns.SpendCombos(s)
		ns.enterCombat(s)



	elseif s.comboPoints < maxComboPtsToSpend then

		-- Combo point building...
		if s.energy >= ns.e.Garrote 
			and s.Garrote_Expiration < s.now + 18 / 4 -- Pandemic
			and s.garroteReadyTime <= s.now then

			-- No garrote bleed active and need combo points.
			spell = "Garrote"
			s.comboPoints = max(maxCombos, s.comboPoints + 1)
			s.energy = s.energy - ns.e.Garrote 
			s.Garrote_Expiration =  ns.pandemicExpiration(s, s.Garrote_Expiration, 18)
			ns.SpendCombos(s)
			if not stealthy or not ns.hasSubterfugeTalent then
				s.garroteReadyTime = s.now + 15
			end
			ns.enterCombat(s)

		elseif ns.hasBlindsideTalent 
			and s.energy >= ns.e.Blindside 
			and s.Blindside_Expiration > 0
			then

			-- No hemorrhage bleed active and you need combo points.
			spell = "Blindside"
			s.comboPoints = s.comboPoints + 1
			s.energy = s.energy - ns.e.Blindside 
			ns.enterCombat(s)

		elseif s.energy >= ns.e.Mutilate  then

			-- Need to build combo points.
			spell = "Mutilate"
			s.comboPoints = s.comboPoints + 2
			s.energy = s.energy - ns.e.Mutilate
			ns.enterCombat(s)

		end
	

	end


	--    A          B                 C      D
	--1 [Tricks] [Vanish]   |  | [Next]  [CofS]
	--2 [Kick  ] [Vendetta] |  | [MForD]?###
	

	local b2 = nil

	if s.vendettaReadyTime <= s.now and
		 s.Rupture_Expiration > s.now and s.energy <= 40 then
		b2 = ns.n.Vendetta
	end

	local c2 = nil
	if ns.hasMarkedForDeathTalent and s.markedForDeathReadyTime <= s.now then
		c2 = ns.n.Marked_for_Death
	else
--		c2 = ns.n.Trinket_1

	end

	local tricksOfTheTradeOk = s.tricksOfTheTradeReadyTime <= s.now and s.isInGroup
	--local trinket1OK = s.trinket1ReadyTime <= s.now



	local kickOk = s.kickReadyTime <= s.now and s.interruptibleName ~= nil

	local d2 = nil
	local rText = ""
	if s.cofsReadyTime <= s.now and s.removeableName ~= "" then
		d2 = ns.n.Cloak_of_Shadows
		rText = s.removeableName
	end

	-- Update state to next intersting time.
	if spell ~= nil then
		s.now = max(s.now, oldNow + ns.globalCooldown)
		s.globalCoolDownExpiration = s.now
	end
	s.now = max(s.now, oldNow + 0.1) -- Always move forward in time at least a little

	local combatEnergyRegenPerSec = s.combatEnergyRegenPerSec
	s.energy = min(ns.maxEnergy, s.energy + combatEnergyRegenPerSec * (s.now - oldNow))

	--return spell, vanishOk, b2, tricksOfTheTradeOk, trinket1OK, kickOk, s.interruptibleName, d2, rText, c2
	return spell, vanishOk, b2, tricksOfTheTradeOk, kickOk, s.interruptibleName, d2, rText, c2
end

function ns.GeOpenerSpellFromStateAssassination(s)
	local spell = nil;
	local oldNow = s.now
	-- Combo spend poiont for Assassination is one less than max because Mutilate gives 2.
	
	local stealthy = s.playerIsStealthed or s.Subterfuge_Expiration > s.now
	local vanishOk = s.vanishReadyTime <= s.now and s.isInGroup
	
	if s.globalCoolDownExpiration > s.now then
		s.now = s.globalCoolDownExpiration
	else
		if s.playerIsStealthed and not s.inCombat then
			spell = "Garrote"
			ns.open.nextMove = "Garrote1"
		elseif ns.open.nextMove == "Garrote1" and ns.lastSpell == "Garrote" then
			ns.open.nextMove = "Mutilate1"
			spell = "Mutilate"
		elseif ns.open.nextMove == "Garrote1" and ns.lastSpell ~= "Garrote" and ns.lastSpell ~= "" then
			ns.open.active = 0
			s = ns.GetState(GetTime())
			--ns.leftText:SetText("|cffFFffFF".."Opener abort: Normal Rotation(1)")
		elseif ns.open.nextMove == "Garrote1" and ns.lastSpell == "" then
			spell = "Garrote"
			ns.open.nextMove = "Garrote1"
		elseif ns.open.nextMove == "Mutilate1" and ns.lastSpell == "Mutilate" then
			ns.open.nextMove = "Rupture"
			spell = "Rupture"
		elseif ns.open.nextMove == "Mutilate1" and ns.lastSpell ~= "Garrote" then
			ns.open.active = 0
			s = ns.GetState(GetTime())
			--ns.leftText:SetText("|cffFFffFF".."Opener abort: Normal Rotation(2)")
		elseif ns.open.nextMove == "Mutilate1" then
			spell = "Mutilate"
		elseif ns.open.nextMove == "Rupture" and ns.lastSpell == "Rupture" then
			if s.vendettaReadyTime <= s.now then
				ns.open.nextMove = "Vendetta"
				spell = "Vendetta"
			elseif s.ToxicBlade_ReadyTime <= s.now then
				ns.open.nextMove = "Toxic Blade"
				spell = "Toxic_Blade"
			elseif vanishOk then
				ns.open.nextMove = "Vanish"
				spell = "Vanish"
				s.vanishReadyTime = s.now + 120
			elseif s.energy >= ns.e.Envenom and s.comboPoints > 0 then
				ns.open.nextMove = "Envenom"
				spell = "Envenom"
			else
				ns.open.nextMove = "Mutilate2"
				spell = "Mutilate"
			end
		elseif ns.open.nextMove == "Rupture" and ns.lastSpell ~= "Mutilate" then
			ns.open.active = 0
			s = ns.GetState(GetTime())
			--ns.leftText:SetText("|cffFFffFF".."Opener abort: Normal Rotation(3)")
		elseif ns.open.nextMove == "Rupture" then
			spell = "Rupture"
		elseif ns.open.nextMove	 == "Vendetta" and ns.lastSpell == "Vendetta" then
			if s.ToxicBlade_ReadyTime <= s.now then
				ns.open.nextMove = "Toxic Blade"
				spell = "Toxic_Blade"
			elseif ns.knowsKingsbane and s.Kingsbane_ReadyTime <= s.now then
				ns.open.nextMove = "Kingsbane"
				spell = "Kingsbane"
			elseif vanishOk then
				ns.open.nextMove = "Vanish"
				spell = "Vanish"
				s.vanishReadyTime = s.now + 120
			elseif s.energy >= ns.e.Envenom and s.comboPoints > 0 then
				ns.open.nextMove = "Envenom"
				spell = "Envenom"
			else
				ns.open.nextMove = "Mutilate2"
				spell = "Mutilate"
			end
		elseif ns.open.nextMove == "Vendetta" and ns.lastSpell ~= "Rupture" then
			ns.open.active = 0
			s = ns.GetState(GetTime())
			--ns.leftText:SetText("|cffFFffFF".."Opener abort: Normal Rotation(4)")
		elseif ns.open.nextMove == "Vendetta" then
			spell = "Vendetta"
		elseif ns.open.nextMove == "Toxic Blade" and ns.lastSpell == "Toxic Blade" then
			if vanishOk then
				ns.open.nextMove = "Vanish"
				spell = "Vanish"
				s.vanishReadyTime = s.now + 120
			elseif s.energy >= ns.e.Envenom and s.comboPoints > 0 then
				ns.open.nextMove = "Envenom1"
				spell = "Envenom"
			else
				ns.open.nextMove = "Mutilate2"
				spell = "Mutilate"
			end
		elseif ns.open.nextMove == "Toxic Blade" and ns.lastSpell ~= "Vendetta" and ns.lastSpell ~= "Rupture" then
			ns.open.active = 0
			s = ns.GetState(GetTime())
			--ns.leftText:SetText("|cffFFffFF".."Opener abort: Normal Rotation(5)")
			ns.enterCombat(s)
		elseif ns.open.nextMove == "Toxic Blade" then
			spell = "Toxic_Blade"
		elseif ns.open.nextMove == "Kingsbane" and ns.lastSpell == "Kingsbane" then
			if vanishOk then
				ns.open.nextMove = "Vanish"
				spell = "Vanish"
				s.vanishReadyTime = s.now + 120
			elseif s.energy >= ns.e.Envenom and s.comboPoints > 0 then
				ns.open.nextMove = "Envenom1"
				spell = "Envenom"
			else
				ns.open.nextMove = "Mutilate2"
				spell = "Mutilate"
			end
		elseif ns.open.nextMove == "Kingsbane" and ns.lastSpell ~= "Toxic Blade" and ns.lastSpell	 ~= "Vendetta" and ns.lastSpell ~= "Rupture" then
			ns.open.active = 0
			s = ns.GetState(GetTime())
			--ns.leftText:SetText("|cffFFffFF".."Opener abort: Normal Rotation(6)")
		elseif ns.open.nextMove == "Kingsbane" then
			spell = "Kingsbane"
		elseif ns.open.nextMove == "Vanish" and ns.lastSpell == "Vanish" then
			if  s.energy >= ns.e.Envenom  and s.comboPoints > 0 then
				ns.open.nextMove = "Envenom1"
				spell = "Envenom"
			else
				ns.open.nextMove = "Mutilate2"
				spell = "Mutilate"
			end
		elseif ns.open.nextMove == "Vanish" and ns.lastSpell ~= "Kingsbane" and ns.lastSpell ~= "Toxic Blade" and ns.lastSpell ~= "Vendetta" and ns.lastSpell ~= "Rupture" then
			ns.open.active = 0
			s = ns.GetState(GetTime())
			--ns.leftText:SetText("|cffFFffFF".."Opener abort: Normal Rotation(7)")
		elseif ns.open.nextMove == "Vanish" then
			spell = "Vanish"
		elseif ns.open.nextMove == "Envenom1" and ns.lastSpell == "Envenom" then
			ns.open.nextMove = "Mutilate2"
			spell = "Mutilate"
		elseif ns.open.nextMove == "Envenom1" and ns.lastSpell ~= "Vanish" and ns.lastSpell ~= "Kingsbane" and ns.lastSpell ~= "Toxic Blade" and ns.lastSpell ~= "Vendetta" and ns.lastSpell ~= "Rupture" then
			ns.open.active = 0
			s = ns.GetState(GetTime())
			--ns.leftText:SetText("|cffFFffFF".."Opener abort: Normal Rotation(8)")
		elseif ns.open.nextMove == "Envenom1" then
			spell = "Envenom"
		elseif ns.open.nextMove == "Mutilate2" and ns.lastSpell == "Mutilate" then
			ns.open.nextMove = "Envenom2"
			spell = "Envenom"
		elseif ns.open.nextMove == "Mutilate2" and ns.lastSpell ~= "Envenom" then
			ns.open.active = 0
			s = ns.GetState(GetTime())
			--ns.leftText:SetText("|cffFFffFF".."Opener abort: Normal Rotation(9)")
		elseif ns.open.nextMove == "Mutilate2" then
			spell = "Mutilate"
		elseif ns.open.nextMove == "Garrote2" and ns.lastSpell == "Garrote" then
			ns.open.active = 0
			s = ns.GetState(GetTime())
			--ns.leftText:SetText("|cffFFffFF".."Opener complete: Normal Rotation(11)")
		elseif ns.open.nextMove == "Garrote2" and ns.lastSpell ~= "Envenom" then
			ns.open.active = 0
			s = ns.GetState(GetTime())
			--ns.leftText:SetText("|cffFFffFF".."Opener abort: Normal Rotation(10)")
		elseif ns.open.nextMove == "Garrote2" then
			spell = "Garrote"
		elseif ns.open.nextMove == "Envenom2" and ns.lastSpell == "Envenom" then
			spell = "Garrote"
			ns.open.nextMove = "Garrote2"
		elseif ns.open.nextMove == "Envenom2" and ns.lastSpell ~= "Mutilate" then
			ns.open.active = 0
			s = ns.GetState(GetTime())
			--ns.leftText:SetText("|cffFFffFF".."Opener abort: Normal Rotation(12)")
		elseif ns.open.nextMove == "Envenom2" then
			spell = "Envenom"
		end
	end

	--    A          B                 C      D
	--1 [Tricks] [Vanish]   |  | [Next]  [CofS]
	--2 [Kick  ] [Vendetta] |  | [MForD]?###
	

	local b2 = nil

	if s.vendettaReadyTime <= s.now and
		 s.Rupture_Expiration > s.now and s.energy <= 40 then
		b2 = ns.n.Vendetta
	end

	local c2 = nil
	if ns.hasMarkedForDeathTalent and s.markedForDeathReadyTime <= s.now then
		c2 = ns.n.Marked_for_Death
	else
--		c2 = ns.n.Trinket_1
	end

	local tricksOfTheTradeOk = s.tricksOfTheTradeReadyTime <= s.now and s.isInGroup
	--local trinket1OK = s.trinket1ReadyTime <= s.now



	local kickOk = s.kickReadyTime <= s.now and s.interruptibleName ~= nil

	local d2 = nil
	local rText = ""
	if s.cofsReadyTime <= s.now and s.removeableName ~= "" then
		d2 = ns.n.Cloak_of_Shadows
		rText = s.removeableName
	end



	-- Update state to next intersting time.
	if spell ~= nil then
		s.now = max(s.now, oldNow + ns.globalCooldown)
		s.globalCoolDownExpiration = s.now
	end
	s.now = max(s.now, oldNow + 0.1) -- Always move forward in time at least a little

	local combatEnergyRegenPerSec = s.combatEnergyRegenPerSec

	s.energy = min(ns.maxEnergy, s.energy + combatEnergyRegenPerSec * (s.now - oldNow))

	return spell, vanishOk, b2, tricksOfTheTradeOk,  kickOk, s.interruptibleName, d2, rText, c2
end

function ns.GeSpellFromStateOutlaw(s)
	local spell = nil;
	local oldNow = s.now

	local maxComboPtsToSpend = 5	
	local maxCombos = 5
	local markedForDeathGrant = 5
	if ns.hasDeeperStrategemTalent then
		maxComboPtsToSpend = 5
		maxCombos = 6
		markedForDeathGrant = 6
	elseif (s.Opportunity_Expiration > s.now + 1.5 and ns.hasQuickDrawTalent) or s.playerIsStealthed then
		maxComboPtsToSpend = 4 -- We'll generate 2 combos with the comming pistol shot or Ambush.
	end

	local eCostMult = 1 -- ### Remvoe if never use in Outlaw

	local rollTheBonesBuffGoodness = 0
	if s.True_Bearing_Expiration > s.now then
		rollTheBonesBuffGoodness = rollTheBonesBuffGoodness + 1
	end
	if s.Ruthless_Precision_Expiration > s.now then
		rollTheBonesBuffGoodness = rollTheBonesBuffGoodness + 1
	end
 	if s.Skull_and_Crossbones_Expiration > s.now then
 		rollTheBonesBuffGoodness = rollTheBonesBuffGoodness + 1
 	end
 	if s.Broadsides_Expiration > s.now then
 		rollTheBonesBuffGoodness = rollTheBonesBuffGoodness + 1
 	end
 	if s.Buried_Treasure_Expiration > s.now then
 		rollTheBonesBuffGoodness = rollTheBonesBuffGoodness + 1
 	end
  	if s.Grand_Melee_Expiration > s.now then
 		rollTheBonesBuffGoodness = rollTheBonesBuffGoodness + 1
 	end


 	local rollTheBonesExpiration = max(s.True_Bearing_Expiration, s.Ruthless_Precision_Expiration,
 		s.Skull_and_Crossbones_Expiration, s.Broadsides_Expiration, s.Buried_Treasure_Expiration,
 		s.Grand_Melee_Expiration)

	if s.globalCoolDownExpiration > s.now then

		-- waiting for global cooldown
		s.now = s.globalCoolDownExpiration

	elseif s.energy >= ns.e.Crimson_Vial * eCostMult
		and s.crimsonVialReadyTime <= s.now
		and s.playerHealthFraction < options.PlayerHealthThreshold / 100
		then

		spell = "Crimson_Vial"
		s.crimsonVialReadyTime = s.now + 30
		s.energy = s.energy - ns.e.Crimson_Vial * eCostMult

--	elseif not s.playerIsStealthed and not s.inCombat and s.stealthReadyTime < s.now then
--
--		-- Always open from stealth
--		spell = "Stealth"
--		s.playerIsStealthed = true
--		s.stealthReadyTime = s.now + 2

	elseif s.comboPoints >= maxComboPtsToSpend -1 and rollTheBonesBuffGoodness < 2
		then
			spell = "Roll_the_Bones"
			-- We don't know what buff will turn up, so that makes it hard to predict the future.
			-- Just assume it is Broadside for the sake of prediciton.
			s.Broadsides_Expiration = s.now + (ns.SpendCombos(s) + 1) * 6
	--elseif s.adrenalineRushReadyTime <= s.now then
	--		spell = "Adrenaline_Rush"

	elseif ns.hasMarkedForDeathTalent
		and s.comboPoints <= 1
		and maxCombos - s.comboPoints >= markedForDeathGrant
		and s.markedForDeathReadyTime <= s.now
		then

		spell = "Marked_for_Death"
		s.markedForDeathReadyTime = s.now + 60
		s.comboPoints = min(maxCombos, s.comboPoints + markedForDeathGrant)

	elseif s.comboPoints >= maxComboPtsToSpend
		and s.Ruthless_Precision_Expiration > s.now
		and s.energy > ns.e.Between_the_Eyes
		and s.Between_the_Eyes_ReadyTime <= s.now
		then

		spell = "Between_the_Eyes"
		s.energy = s.energy - ns.e.Between_the_Eyes
		s.Between_the_Eyes_ReadyTime = s.now + 20
		ns.enterCombat(s)
		ns.SpendCombos(s)

	elseif s.comboPoints >= maxComboPtsToSpend
		and s.energy >= ns.e.Dispatch * eCostMult
		then

		spell = "Dispatch"
		s.energy = s.energy - ns.e.Dispatch * eCostMult
		ns.enterCombat(s)
		ns.SpendCombos(s)

	elseif s.Opportunity_Expiration > s.now
		and s.comboPoints < maxComboPtsToSpend -1 
		and s.energy > ns.e.Pistol_Shot	--todo: restrict if energy will cap during expiration
		then

		-- Special case of low combo points plus Opportuniy proc triggering pistol
		-- shot so it comes in before a Dreadblades sinister slash.
		spell = "Pistol_Shot"
		s.comboPoints = s.comboPoints + 1
		if ns.hasQuickDrawTalent then
			s.comboPoints = s.comboPoints + 1
		end
		s.energy = s.energy - ns.e.Pistol_Shot
		s.Opportunity_Expiration = s.now
		ns.enterCombat(s)

	--elseif s.Curse_of_the_Dreadblades_Expiration > s.now
	--	and s.Opportunity_Expiration > s.now
	--	and s.comboPoints < maxComboPtsToSpend
	--	and s.energy > ns.e.Pistol_Shot
	--	then

	--	-- Special case of low combo points plus Opportuniy proc triggering pistol
	--	-- shot so it comes in before a Dreadblades sinister slash.
	--	spell = "Pistol_Shot"
	--	s.comboPoints = s.comboPoints + 1
	--	if ns.hasQuickDrawTalent then
	--		s.comboPoints = s.comboPoints + 1
	--	end
	--	s.energy = s.energy - ns.e.Pistol_Shot
	--	s.Opportunity_Expiration = s.now
	--	ns.enterCombat(s)

	--elseif s.Curse_of_the_Dreadblades_Expiration > s.now
	--	and s.comboPoints < maxComboPtsToSpend
	--	and s.energy >= ns.e.Sinister_Strike
	--	then

	--	-- Special case high priority Sinister Slash if Dreadblades is active.
	--	spell = "Sinister_Strike"
	--	s.energy = s.energy - ns.e.Sinister_Strike
	--	s.comboPoints = maxCombos
	--	ns.enterCombat(s)

	--elseif not ns.hasSliceAndDiceTalent
	--	and s.comboPoints >= maxComboPtsToSpend
	--  and ((not s.isInGroup and rollTheBonesBuffGoodness < 1)
	--    	-- Shark Infested Waters is good. True Bearing is good if you are waiting for
	--    	-- AR to come off cooldown by, say 10 s or more. Else any two are good.
	--    	or (rollTheBonesBuffGoodness < 2
	--    		and s.Ruthless_Precision_Expiration <= s.now
	--    		and (s.True_Bearing_Expiration <= s.now or s.adrenalineRushReadyTime <= s.now + 10)))
	--	then

	--	spell = "Roll_the_Bones"
	--	-- We don't know what buff will turn up, so that makes it hard to predict the future.
	--	-- Just assume it is Broadside for the sake of prediciton.
	--	s.Broadsides_Expiration = s.now + (ns.SpendCombos(s) + 1) * 6

	--elseif ns.hasMarkedForDeathTalent
	--	and s.comboPoints <= 1
	--	and maxCombos - s.comboPoints >= markedForDeathGrant
	--	and s.markedForDeathReadyTime <= s.now
	--	then

	--	spell = "Marked_for_Death"
	--	s.markedForDeathReadyTime = s.now + 60
	--	s.comboPoints = min(maxCombos, s.comboPoints + markedForDeathGrant)

	--elseif s.playerIsStealthed and s.energy > ns.e.Ambush * eCostMult then

	--	spell = "Ambush"
	--	s.energy = s.energy - ns.e.Ambush * eCostMult
	--	s.comboPoints = max(maxCombos, s.comboPoints + 2)
	--	ns.enterCombat(s)

	--elseif s.comboPoints >= maxComboPtsToSpend
	--	and s.Ruthless_Precision_Expiration > s.now
	--	and s.energy > ns.e.Between_the_Eyes
	--	and s.Between_the_Eyes_ReadyTime <= s.now
	--	then

	--	spell = "Between_the_Eyes"
	--	s.energy = s.energy - ns.e.Between_the_Eyes
	--	s.Between_the_Eyes_ReadyTime = s.now + 20
	--	ns.enterCombat(s)
	--	ns.SpendCombos(s)

	--elseif ns.hasSliceAndDiceTalent
	--	and s.comboPoints >= 1
	--	and s.Slice_and_Dice_Expiration <= (s.comboPoints + 1) * 6 / 4 -- Pandemic
	--	and s.energy > ns.e.Slice_and_Dice
	--	then

	--	spell = "Slice_and_Dice"
	--	s.energy = s.energy - ns.e.Slice_and_Dice
	--	local comboSpend = ns.SpendCombos(s)
	--	s.Slice_and_Dice_Expiration = ns.pandemicExpiration(s, s.Slice_and_Dice_Expiration, (s.comboPoints + 1) * 6)
	--	ns.enterCombat(s)

	--elseif s.comboPoints >= maxComboPtsToSpend
	--	and s.energy >= ns.e.Dispatch * eCostMult
	--	then

	--	spell = "Dispatch"
	--	s.energy = s.energy - ns.e.Dispatch * eCostMult
	--	ns.enterCombat(s)
	--	ns.SpendCombos(s)

	--elseif s.comboPoints < maxComboPtsToSpend
	--	and s.Curse_of_the_Dreadblades_Expiration <= s.now
	--	then

		-- Combo point building. But only if Dreadblades is not active. If it is, we should
		-- only be using the Sinister Slash and Pistol Shot cases earlier.
	--	if s.playerIsStealthed and s.energy > ns.e.Ambush * eCostMult then

	--		spell = "Ambush"
	--		s.energy = s.energy - ns.e.Ambush * eCostMult
	--		s.comboPoints = s.comboPoints + 2
	--		ns.enterCombat(s)

	--	elseif s.Opportunity_Expiration > s.now
	--		and s.energy > ns.e.Pistol_Shot
	--		then

	--		spell = "Pistol_Shot"
	--		s.comboPoints = s.comboPoints + 1
	--		if ns.hasQuickDrawTalent then
	--			s.comboPoints = s.comboPoints + 1
	--		end
	--		s.energy = s.energy - ns.e.Pistol_Shot
	--		s.Opportunity_Expiration = s.now
	--		ns.enterCombat(s)

	--	elseif ns.hasGhostlyStrikeTalent
	--		and s.energy > ns.e.Ghostly_Strike
	--		and s.Ghostly_Strike_Expiration < s.now + 15 / 4 -- Pandemic
	--		then

	--		spell = "Ghostly_Strike"
	--		s.comboPoints = s.comboPoints + 1
	--		s.Ghostly_Strike_Expiration = ns.pandemicExpiration(s, s.Ghostly_Strike_Expiration, 15)
	--		s.energy = s.energy - ns.e.Ghostly_Strike
	--		ns.enterCombat(s)
		
	elseif s.energy >= ns.e.Sinister_Strike then
		spell = "Sinister_Strike"
		s.energy = s.energy - ns.e.Sinister_Strike
		s.comboPoints = s.comboPoints + 1
		ns.enterCombat(s)
	end

	

	--    A          B                     C      D
	--1 [Tricks] [Vanish]          |  | [Next]   [CofS]
	--2 [Kick  ] [Adrenaline Rush] |  | [Dreadblades]

	local b2 = nil
	if s.adrenalineRushReadyTime <= s.now
		and ((rollTheBonesBuffGoodness >= 2 and rollTheBonesExpiration >= s.now + 30)  -- Say
		or ns.hasSliceAndDiceTalent)
		then

		b2 = ns.n.Adrenaline_Rush
	end

	local c2 = nil
	if ns.knowsCurse_of_the_DreadBlades and s.Curse_of_the_Dreadblades_ReadyTime < s.now then
		c2 = ns.n.Curse_of_the_Dreadblades
	end

	local tricksOfTheTradeOk = s.tricksOfTheTradeReadyTime <= s.now and s.isInGroup
	--local trinket1OK = s.trinket1ReadyTime <= s.now

	local kickOk = s.kickReadyTime <= s.now and s.interruptibleName ~= nil

	local d2 = nil
	local rText = ""
	if s.cofsReadyTime <= s.now and s.removeableName ~= "" then
		d2 = ns.n.Cloak_of_Shadows
		rText = s.removeableName
	end

	-- Update state to next intersting time.
	if spell ~= nil then
		s.now = max(s.now, oldNow + ns.globalCooldown)
	end
	s.globalCoolDownExpiration = s.now
	s.now = max(s.now, oldNow + 0.1) -- Always move forward in time at least a little
	s.energy = min(ns.maxEnergy, s.energy + s.combatEnergyRegenPerSec * (s.now - oldNow))

	return spell, vanishOk, b2, tricksOfTheTradeOk, kickOk, s.interruptibleName, d2, rText, c2
end

function ns.GeSpellFromStateSubtlety(s)
	local spell = nil;
	local oldNow = s.now

	local stealthy = s.playerIsStealthed or s.Shadow_Dance_Expiration > s.now or s.Subterfuge_Expiration > s.now

	local maxComboPtsToSpend = 5
	local maxCombos = 5
	local markedForDeathGrant = 5
	if ns.hasDeeperStrategemTalent then
		maxComboPtsToSpend = 6
		maxCombos = 6
		markedForDeathGrant = 6
	end
	if s.Shadow_Blades_Expiration > s.now then
		maxComboPtsToSpend = maxComboPtsToSpend - 1
	end

	local eCostMult = 1
	if ns.hasShadowFocusTalent and stealthy then
		eCostMult = 0.75
	end

	-- Symbols of death unaffaffected by global cooldown.
	--if stealthy
	--	and s.symbolsOfDeathReadyTime < s.now
	--	and s.Symbols_of_Death_Expiration < s.now + 35 / 4 -- Pandemic
	--	and s.energy > ns.e.SymbolsOfDeath * eCostMult then
--
--		-- "Should be up always
--		spell = "Symbols_of_Death"
--		s.energy = s.energy - ns.e.SymbolsOfDeath * eCostMult
--		s.symbolsOfDeathReadyTime = s.now + 10
--		s.Symbols_of_Death_Expiration = ns.pandemicExpiration(s, s.Symbols_of_Death_Expiration, 35)

	if s.globalCoolDownExpiration > s.now then

		-- waiting for global cooldown
		s.now = s.globalCoolDownExpiration 

	elseif s.energy >= ns.e.Crimson_Vial * eCostMult
		and s.crimsonVialReadyTime <= s.now
		and s.playerHealthFraction < options.PlayerHealthThreshold / 100
		then

		spell = "Crimson_Vial"
		s.crimsonVialReadyTime = s.now + 30
		s.energy = s.energy - ns.e.Crimson_Vial * eCostMult

	elseif not s.playerIsStealthed and not s.inCombat and s.stealthReadyTime < s.now then

		-- Always open from stealth
		spell = "Stealth"
		s.playerIsStealthed = true
		s.stealthReadyTime = s.now + 2


	elseif s.Nightblade_Expiration < s.now + (6 + 2 * s.comboPoints) / 4 -- Pandemic
		and s.comboPoints >= maxComboPtsToSpend
		and s.energy > ns.e.Nightblade * eCostMult
		then

		-- keep nighblade up
		spell = "Nightblade"
		s.energy = s.energy - ns.e.Nightblade * eCostMult
		local comboSpend = ns.SpendCombos(s)
		s.Nightblade_Expiration = ns.pandemicExpiration(s, s.Nightblade_Expiration, (comboSpend * 2 + 6))
		ns.enterCombat(s)

	elseif s.inCombat and s.shadowBladesReadyTime <= s.now then

		spell = "Shadow_Blades"
		s.shadowBladesReadyTime = s.now + 180		
		ns.enterCombat(s)

	--todo Shadowdance determination needs looked into
	elseif not stealthy
		and ((s.shadowDanceChargesAvail > 1 and not ns.hasEnvelopingShadowTalent) or (s.shadowDanceChargesAvail > 2 and ns.hasEnvelopingShadowTalent))
		and s.Shadow_Dance_Expiration <= s.now
		--and (s.comboPoints <= 1 or s.Symbols_of_Death_Expiration < s.now + 30 / 4)
		and (s.energy >= 90 or (ns.hasMasterOfShadowsTalent and s.energy > 80))
		then
		-- Only shadow dance with high energy to take advantage of the 3+ seconds of stealthyness.
			spell = "Shadow_Dance"
			s.shadowDanceChargesAvail = s.shadowDanceChargesAvail - 1
			s.Shadow_Dance_Expiration = s.now + 3
			if s.hasSubterfugeTalent then
				s.Shadow_Dance_Expiration = s.Shadow_Dance_Expiration + 2
			end
			if ns.hasMasterOfShadowsTalent then
				s.energy = min(ns.maxEnergy, s.energy + 25)
			end

	elseif s.Shadow_Dance_Expiration > s.now and s.Symbols_of_Death_Expiration <= s.now then
		spell = "Symbols_of_Death"
		s.energy = s.energy - ns.e.SymbolsOfDeath * eCostMult
		s.symbolsOfDeathReadyTime = s.now + 10
		s.Symbols_of_Death_Expiration = ns.pandemicExpiration(s, s.Symbols_of_Death_Expiration, 35)

	elseif ns.hasMarkedForDeathTalent
		and s.comboPoints <= 1
		and maxCombos - s.comboPoints >= markedForDeathGrant
		and s.markedForDeathReadyTime <= s.now
		then

		spell = "Marked_for_Death"
		s.markedForDeathReadyTime = s.now + 60
		s.comboPoints = min(maxCombos, s.comboPoints + markedForDeathGrant)

	--todo.  Look into Mantle of the Master Assasin/Secret Technique
	elseif s.vanishReadyTime <= s.now and s.inCombat and s.comboPoints <3 and s.isInGroup then
		spell = "Vanish"
		s.vanishReadyTime = s.now + 120

	elseif s.energy >= ns.e.Eviscerate * eCostMult
		and s.comboPoints >= maxComboPtsToSpend
		then

		-- dump combo points
		spell = "Eviscerate"
		ns.SpendCombos(s)
		s.energy = s.energy - ns.e.Eviscerate * eCostMult
		ns.enterCombat(s)


	elseif s.energy >= ns.e.Backstab * eCostMult then

			-- Need to build combo points.
			spell = "Backstab"
			s.comboPoints = s.comboPoints + 1
			if s.Shadow_Blades_Expiration > s.now then
				s.comboPoints = s.comboPoints + 1
			end
			s.energy = s.energy - ns.e.Backstab * eCostMult
			ns.enterCombat(s)
	end



	--elseif s.playerIsStealthed and not s.inCombat and s.Shadow_Blades_Expiration > s.now then
	--	spell = "Shadowstrike"
	--		s.comboPoints = s.comboPoints + 1
	--		if ns.hasPremeditationTalent then
	--			s.comboPoints = s.comboPoints + 1
	--		end
	--		if s.Shadow_Blades_Expiration > s.now then
	--			s.comboPoints = s.comboPoints + 1
	--		end
	--		s.energy = s.energy - ns.e.Shadowstrike * eCostMult
	--		ns.enterCombat(s)
	

	-- if you can cast Shadowstrike, and you just vanished yet remain in combat (and are in a group) - Go Shadowstrike
	--elseif s.energy >= ns.e.Shadowstrike * eCostMult and s.inCombat and stealthy  then
	--	spell = "Shadowstrike"
	--		s.comboPoints = s.comboPoints + 1
	--		if ns.hasPremeditationTalent then
	--			s.comboPoints = s.comboPoints + 1
	--		end
	--		if s.Shadow_Blades_Expiration > s.now then
	--			s.comboPoints = s.comboPoints + 1
	--		end
	--		s.energy = s.energy - ns.e.Shadowstrike * eCostMult
	--		ns.enterCombat(s)
	-- if you're in combat, and Shadowblades is available - go
	--elseif s.inCombat and s.Shadow_Blades_Expiration <= s.now then

	--	spell = "Shadow_Blades"
	--	s.shadowBladesReadyTime = s.now + 180		
	--	ns.enterCombat(s)

	--elseif s.Nightblade_Expiration < s.now + (6 + 2 * s.comboPoints) / 4 -- Pandemic
	--	and s.comboPoints >= maxComboPtsToSpend
	--	and s.energy > ns.e.Nightblade * eCostMult
	--	then

		-- keep nighblade up
	--	spell = "Nightblade"
	--	s.energy = s.energy - ns.e.Nightblade * eCostMult
	--	local comboSpend = ns.SpendCombos(s)
	--	s.Nightblade_Expiration = ns.pandemicExpiration(s, s.Nightblade_Expiration, (comboSpend * 2 + 6))
	--	ns.enterCombat(s)

	--elseif not stealthy
	--	and ((s.shadowDanceChargesAvail > 1 and not ns.hasEnvelopingShadowTalent) or (s.shadowDanceChargesAvail > 2 and ns.hasEnvelopingShadowTalent))
	--	and s.Shadow_Dance_Expiration <= s.now
	--	--and (s.comboPoints <= 1 or s.Symbols_of_Death_Expiration < s.now + 30 / 4)
	--	and (s.energy >= 90 or (ns.hasMasterOfShadowsTalent and s.energy > 80))
	--	then
	--	-- Only shadow dance with high energy to take advantage of the 3+ seconds of stealthyness.
	--		spell = "Shadow_Dance"
	--		s.shadowDanceChargesAvail = s.shadowDanceChargesAvail - 1
	--		s.Shadow_Dance_Expiration = s.now + 3
	--		if s.hasSubterfugeTalent then
	--			s.Shadow_Dance_Expiration = s.Shadow_Dance_Expiration + 2
	--		end
	--		if ns.hasMasterOfShadowsTalent then
	--			s.energy = min(ns.maxEnergy, s.energy + 25)
	--		end
	--elseif s.Shadow_Dance_Expiration > s.now and s.Symbols_of_Death_Expiration <= s.now then
	--	spell = "Symbols_of_Death"
	--	s.energy = s.energy - ns.e.SymbolsOfDeath * eCostMult
	--	s.symbolsOfDeathReadyTime = s.now + 10
	--	s.Symbols_of_Death_Expiration = ns.pandemicExpiration(s, s.Symbols_of_Death_Expiration, 35)

	--elseif s.vanishReadyTime <= s.now and s.comboPoints <3 and s.isInGroup then
	--	spell = "Vanish"
	--	s.vanishReadyTime = s.now + 120
		
	--elseif ns.hasDeathFromAboveTalent
	--	and s.comboPoints >= maxComboPtsToSpend
	--	and s.deathFromAboveReadyTime <= s.now
	--	and s.energy > ns.e.Death_from_Above * eCostMult
	--	then

	--	spell = "Death_from_Above"
	--	s.deathFromAboveReadyTime = s.now + 20
	--	s.energy = s.energy - ns.e.Death_from_Above * eCostMult
	--	ns.enterCombat(s)
	--	ns.SpendCombos(s)
	

	--elseif ns.hasMarkedForDeathTalent
	--	and s.comboPoints <= 1
	--	and maxCombos - s.comboPoints >= markedForDeathGrant
	--	and s.markedForDeathReadyTime <= s.now
	--	then

	--	spell = "Marked_for_Death"
	--	s.markedForDeathReadyTime = s.now + 60
	--	s.comboPoints = min(maxCombos, s.comboPoints + markedForDeathGrant)
	
	

	--elseif s.energy >= ns.e.Eviscerate * eCostMult
	--	and s.comboPoints >= maxComboPtsToSpend
	--	then

		-- dump combo points
	--	spell = "Eviscerate"
	--	ns.SpendCombos(s)
	--	s.energy = s.energy - ns.e.Eviscerate * eCostMult
	--	ns.enterCombat(s)

	--elseif s.comboPoints < maxComboPtsToSpend then

		-- Combo point building...
	--	if stealthy and s.energy >= ns.e.Shadowstrike * eCostMult then

			-- Need to buil combos and can shadowstrike.
	--		spell = "Shadowstrike"
	--		s.comboPoints = s.comboPoints + 1
	--		if ns.hasPremeditationTalent then
	--			s.comboPoints = s.comboPoints + 1
	--		end
	--		if s.Shadow_Blades_Expiration > s.now then
	--			s.comboPoints = s.comboPoints + 1
	--		end
	--		s.energy = s.energy - ns.e.Shadowstrike * eCostMult
	--		ns.enterCombat(s)

	--	elseif not stealthy and ns.knowsGoremaws_Bite
	--		and s.Goremaws_Bite_ReadyTime <= s.now
	--		and s.comboPoints < 3
	--		and s.energy < 50
	--		then

	--		spell = "Goremaws_Bite"
	--		s.Goremaws_Bite_ReadyTime = s.now + 60
	--		s.comboPoints = s.comboPoints + 3
	--		if s.Shadow_Blades_Expiration > s.now then
	--			s.comboPoints = min(maxCombos, s.comboPoints + 1)
	--		end
	--		ns.enterCombat(s)

	--	elseif ns.hasGloombladeTalent and s.energy >= ns.e.Gloomblade * eCostMult then

			-- Need to build combo points.
	--		spell = "Gloomblade"
	--		s.comboPoints = s.comboPoints + 1
	--		if s.Shadow_Blades_Expiration > s.now then
	--			s.comboPoints = s.comboPoints + 1
	--		end
	--		s.energy = s.energy - ns.e.Gloomblade * eCostMult
	--		ns.enterCombat(s)

	--	elseif s.energy >= ns.e.Backstab * eCostMult then

			-- Need to build combo points.
	--		spell = "Backstab"
	--		s.comboPoints = s.comboPoints + 1
	--		if s.Shadow_Blades_Expiration > s.now then
	--			s.comboPoints = s.comboPoints + 1
	--		end
	--		s.energy = s.energy - ns.e.Backstab * eCostMult
	--		ns.enterCombat(s)

	--	end
	--end

	local vanishOk = s.vanishReadyTime <= s.now and s.isInGroup

	--    A          B                 C      D
	--1 [Tricks] [Vanish]        |  | [Next] [CofS]
	--2 [Kick  ] [Shadow Blades] |  |

	local b2 = nil
	if s.shadowBladesReadyTime <= s.now then
		b2 = ns.n.Shadow_Blades
	end

	local tricksOfTheTradeOk = s.tricksOfTheTradeReadyTime <= s.now and s.isInGroup
	--local trinket1OK = s.trinket1ReadyTime <= s.now

	local kickOk = s.kickReadyTime <= s.now and s.interruptibleName ~= nil

	local d2 = nil
	local rText = ""
	if s.cofsReadyTime <= s.now and s.removeableName ~= "" then
		d2 = ns.n.Cloak_of_Shadows
		rText = s.removeableName
	end

	-- Update state to next intersting time. Symbols of Death doesn't trigger global cooldown.
	if spell ~= nil and spell ~= "Symbols_of_Death" then
		s.now = max(s.now, oldNow + ns.globalCooldown)
	end
	s.globalCoolDownExpiration = s.now
	s.now = max(s.now, oldNow + 0.1) -- Always move forward in time at least a little
	s.energy = min(ns.maxEnergy, s.energy + s.combatEnergyRegenPerSec * (s.now - oldNow))

	return spell, vanishOk, b2, tricksOfTheTradeOk, kickOk, s.interruptibleName, d2, rText, nil
end

function ns.enterCombat(s)
	if s.playerIsStealthed and ns.spec ~= "Outlaw" and ns.hasSubterfugeTalent then
		s.Subterfuge_Expiration = s.now + 3
	end
	s.playerIsStealthed = false
	s.inCombat = true
	
end

-- Spend combos in state. Returns how many spent, which might not be all because of Anticipatopn.
function ns.SpendCombos(s)
	local spend = s.comboPoints
	s.comboPoints = s.comboPoints - spend
	return spend
end

-- Returns when a spell subject to Pandemic will expire if cast s.now. The Pandemic mechanic
-- allows any remaining duration of a spell less than 25% of its normal duration to add to
-- a new cast's duration. Interestingly, for spells with duration dependent on combo poinst (say)
-- it is the current combo point value that determins duration, not duration it was cast with
-- (because that's obviusly been forgotten).
function ns.pandemicExpiration(s, curExpiration, basicDuration)
	return s.now + basicDuration + min(max(0, curExpiration - s.now), basicDuration / 4)
end

-- spell is a non-localised name.
function ns.saySpell(spell)
	--[[]
	var inExceptions = false
	var lowerSpell = strlower(ns.n[spell])
	for exception in string.gmatch(str, ' *([^,]+) *') do
		if strfind(exception, lowerSpell) then
			inExceptions = true
			break
		end
	end
	--]]
	if options.SoundChannel ~= "No sound" then
		-- Try to play localised version, is present.
		local willPlay = PlaySoundFile("Interface\\AddOns\\Mutilate\\media\\"..ns.n[spell]..".mp3", options.SoundChannel)
		if not willPlay and ns.n[spell] ~= spell then
			-- Failing that, play English (if it is different)
			PlaySoundFile("Interface\\AddOns\\Mutilate\\media\\"..spell..".mp3", options.SoundChannel)
		end
	end
end

-- Blanks out all icon textures and forgets what we said last.
function ns.ClearUI()
	ns.textureRecommend:SetTexture(nil)
	ns.textureA1:SetTexture(nil)
	ns.textureA2:SetTexture(nil)
	ns.textureB1:SetTexture(nil)
	ns.textureB2:SetTexture(nil)
	ns.textureC1:SetTexture(nil)
	ns.textureD1:SetTexture(nil)

	ns.saidSpell = nil
	ns.saidKick = false
end

function ns.DecideSpells()

	local now = GetTime()
	if now - ns.lastUpdateTime < 0.05 then
		return -- This is our main throttle to OnUpdate to prevent running too often.
	end
	ns.lastUpdateTime = now
	
	local guid = UnitGUID("target")
	
	if  UnitName("target") == nil or UnitIsFriend("player", "target") or UnitHealth("target") == 0 then
		return -- ignore the dead and friendly
	end

	if guid == nil then
		ns.ClearUI()
		return
	end

	local s = ns.GetState(now)
	if s == nil then
		-- In period of confusion following start of global cooldown.
		
		ns.textureRecommend:SetTexture(nil)
		return
	end

	local priorState
	if options.ConsoleTrace or ns.selfCheck then
		-- Remember the state so we can say what led to the decision.
		if options.ConsoleTrace and ns.textureRecommend == nil then
				print("---priorState")
		end
		priorState = ns.shallowCopyOfTable(s)
	end

	local globalCoolDownExpiration = s.globalCoolDownExpiration
	--local spell, vanishOk, b2, tricksOfTheTradeOk, trinket1OK, kickOk, interruptibleName, d2, rText, c2 = ns.GetSpellFromState(s, "=")
	local spell, vanishOk, b2, tricksOfTheTradeOk, kickOk, interruptibleName, d2, rText, c2 = ns.GetSpellFromState(s, "=")
	
	--local trinket1OK = s.trinket1ReadyTime <= s.now
	
	if tricksOfTheTradeOk then
		ns.textureA1:SetTexture(GetSpellTexture(ns.n.Tricks_of_the_Trade))
	else
		ns.textureA1:SetTexture(nil)
	end

	--if trinket1OK then
	--	ns.textureD1:SetTexture(select(10, GetItemInfo(151190))) -- set to Trinket ID if using one..
	--else
		--print("Trinket not ready")
		ns.textureD1:SetTexture(nil)
	--end

	if vanishOk then
		ns.textureB1:SetTexture(GetSpellTexture(ns.n.Vanish))
	else
		ns.textureB1:SetTexture(nil)
	end
	
	ns.textureB2:SetTexture(GetSpellTexture(b2)) -- Vendetta, Shadow Blades
	ns.textureC2:SetTexture(GetSpellTexture(c2)) -- Marked for Death
	ns.textureD2:SetTexture(GetSpellTexture(d2)) -- Cloak of Shadows
	if rText ~= nil then
		ns.rightText:SetText("|cffFFffFF"..rText) -- Cloak of Shadows text
	else
		ns.rightText:SetText("")
	end

	if kickOk then
		ns.textureA2:SetTexture(GetSpellTexture(ns.n.Kick))
	--	ns.leftText:SetText("|cffFFffFF"..interruptibleName)
		if not ns.saidKick then
			ns.saySpell("Kick")
			ns.saidKick = true
		end
	else
		ns.textureA2:SetTexture(nil)
		--ns.leftText:SetText("")
		ns.saidKick = false
	end

	-- Try to predict next required spell by walking the state forward in time till the spell decider
	-- returns non-nil. This is a bit crude. To be better we would jump forward to the minimium of all
	-- the future expirations and ready times and the time when energy regen hits some spell
	-- requirement.
	local i = 0
	local nextSpell = nil
	local nextNextSpell = nil
	local whenNext = now
	local priorNextState
	if options.ConsoleTrace and ns.textureRecommend == nil then
				print("---Predict")
	end
	while i < 40 do
		local priorNow = s.now
		local priorNextStateTemp
		if (options.ConsoleTrace or ns.selfCheck) and nextSpell == nil and priorNextState == nil then
			priorNextStateTemp = ns.shallowCopyOfTable(s)
		end
		spellFromState = ns.GetSpellFromState(s)
		if spellFromState ~= nil then
			if nextSpell == nil then
				nextSpell = spellFromState
				whenNext = priorNow
				priorNextState = priorNextStateTemp
				if spell ~= nil then
					break -- Don't need a nextNextSpell once we have non-nil spell and nextSpell.
				end
			else
				nextNextSpell = spellFromState
				break
			end
		end
		i = i + 1
	end

	if ns.selfCheck then
		if options.ConsoleTrace and ns.textureRecommend == nil then
				print("---selfcheck")
		end
		if spell ~= nil and ns.priorSpell == nil and ns.priorNextSpell ~= spell then
			--print("===Bad prediction", ns.priorNextSpell, "became", spell)
		end
		if spell ~= nil and ns.priorSpell == nil and spell ~= ns.initialPrediction and ns.initialPrediction ~= nil then
			print("===Bad initial prediction",  ns.initialPrediction, "became", spell)
			print("Predicated state giving", ns.initialPrediction, ns.StateSummary(ns.initialPredictionState))
			print("Actual state giving", spell, ns.StateSummary(priorState))
		end
		if spell == nil and ns.priorSpell ~= nil then
			ns.initialPrediction = nextSpell
			ns.initialPredictionState = priorNextState
		end
	end

	-- Now we have spell, nextSpell, and nextNextSpell; any of which may be nil.
	local shouldSay
	if spell ~= nil then
		if options.ConsoleTrace and ns.textureRecommend == nil then
				print("---spell nil")
		end
		if ns.priorSpell == nil and ns.priorNextSpell ~= nil then
			-- We have a current spell ready. Before now, we were showing a nextSpell in the main
			-- slot with a cooldown timer running. So cancel that now.
			ns.spellCooldownFrame:SetCooldown(0, 0)
		end
		ns.textureRecommend:SetTexture(GetSpellTexture(ns.n[spell]))
		if nextSpell ~= nil then
			ns.textureC1:SetTexture(GetSpellTexture(ns.n[nextSpell]))
		else
			ns.textureC1:SetTexture(nil)
		end
		shouldSay = spell
		if ns.reportedSpell ~= spell then
			if options.ConsoleTrace then
				print("---"..ns.addOnName.."---")
				print(ns.StateSummary(priorState))
				print("Therefore", spell)
			end
			ns.reportedSpell = spell
		end
	else
		ns.reportedSpell = nil
		if nextSpell ~= nil then
			if ns.priorSpell ~= nil or ns.currentCooldownEnd == nil then
				-- We have no main spell, yet we used to be showing one. This is zero time for
				-- the cooldown timer. Hopefully our initial time estimate is accurate, but things
				-- can disturb it. Especially unpredicatble procs.
				ns.mainSpellBlankedTime = now
				ns.spellCooldownFrame:SetCooldown(ns.mainSpellBlankedTime, whenNext - ns.mainSpellBlankedTime)
				ns.currentCooldownEnd = whenNext
			end
			if abs(whenNext - ns.currentCooldownEnd) > 0.05 then
				-- Update cooldown time if it has shifted more than a threshold. Could be lots of
				-- causes for this. We have the theshold just to cut down on jtter.
				ns.spellCooldownFrame:SetCooldown(ns.mainSpellBlankedTime, whenNext - ns.mainSpellBlankedTime)
				ns.currentCooldownEnd = whenNext
			end
			if ns.priorSpell ~= nil then
				ns.saidSpell = nil
			end
			if ns.currentCooldownEnd - now < options.VoiceLeadTime then
				shouldSay = nextSpell
			end
			ns.textureRecommend:SetTexture(GetSpellTexture(ns.n[nextSpell]))
			if nextNextSpell ~= nil and ns.open.active == 0 then
				ns.textureC1:SetTexture(GetSpellTexture(ns.n[nextNextSpell]))
			else
				ns.textureC1:SetTexture(nil)
			end
		else
			-- We have no spell and no next spell.
			ns.textureRecommend:SetTexture(nil)
			ns.textureC1:SetTexture(nil) -- Should be already, but just in case.
			s = ns.GetState(now)
			nextSpell = ns.GetSpellFromState(s)

		end
	end

	if ns.saidSpell ~= shouldSay then
		if shouldSay ~= nil then
			ns.saySpell(shouldSay)
			ns.saidSpell = shouldSay
		end
	end


	if options.ConsoleTrace and nextSpell ~= nil and nextSpell ~= ns.priorNextSpell then
		print("State at T+"..string.format("%.2f", priorNextState.now - priorState.now),
			ns.StateSummary(priorNextState))
		print("Follow on spell therefore", nextSpell)
		
	end
	ns.priorSpell = spell
	ns.priorNextSpell = nextSpell
	ns.priorNextNextSpell = nextNextSpell

end

function ns.CreateOptionFrame()
	local panel = CreateFrame("FRAME", "MutilateOptions");
	panel.name = "Mutilate";
	panel:Hide()
	--panel:SetPoint("CENTER")
	--panel:SetSize(20,20)

	local y = -10
	local lineStep = 40

	local fstring1 = panel:CreateFontString("MutilateOptions_string1", "OVERLAY", "GameFontNormal")
	fstring1:SetText("Lock panel position")
	fstring1:SetPoint("TOPLEFT", 10, y)

	local checkbox1 = CreateFrame("CheckButton", "$parent_cb1", panel, "OptionsCheckButtonTemplate")
	checkbox1:SetWidth(18)
	checkbox1:SetHeight(18)
	checkbox1:SetScript("OnClick", function() ns.ToggleLocked() end)
	checkbox1:SetPoint("TOPRIGHT", -10, y)
	checkbox1:SetChecked(ns.GetLocked())
	y = y - lineStep
	
	--
	-- GUI Scale
	--
	local fstring5 = panel:CreateFontString("MutilateOptions_string5", "OVERLAY", "GameFontNormal")
	fstring5:SetText("GUI Scale")
	fstring5:SetPoint("TOPLEFT", 10, y)

	local slider5 = CreateFrame("Slider", "$parent_sl", panel, "OptionsSliderTemplate")
	slider5:SetMinMaxValues(.5, 1.5)
	slider5:SetValue(options.scale)
	slider5:SetValueStep(1.0 / 16)
	slider5:SetObeyStepOnDrag(true)
	slider5:SetScript("OnValueChanged", function(self) ns.SetScale(self:GetValue()); getglobal(self:GetName() .. "Text"):SetText(self:GetValue())  end)
	getglobal(slider5:GetName() .. "Low"):SetText("0.5")
	getglobal(slider5:GetName() .. "High"):SetText("1.5")
	getglobal(slider5:GetName() .. "Text"):SetText(options.scale)
	slider5:SetPoint("TOPRIGHT", -10, y)
	y = y - lineStep

	--
	-- Crimson Vial player health threshold
	--
	local fstring11 = panel:CreateFontString("MutilateOptions_string11", "OVERLAY", "GameFontNormal")
	fstring11:SetText("Suggest Crimson Vial when your health is below this %")
	fstring11:SetPoint("TOPLEFT", 10, y)
	local slider11 = CreateFrame("Slider", "$parent_s7", panel, "OptionsSliderTemplate")
	slider11:SetMinMaxValues(0, 100)
	slider11:SetValue(options.PlayerHealthThreshold)
	slider11:SetValueStep(1)
	slider11:SetObeyStepOnDrag(true)
	slider11:SetScript("OnValueChanged", function(self) options.PlayerHealthThreshold = self:GetValue(); getglobal(self:GetName() .. "Text"):SetText(self:GetValue().."%")  end)
	getglobal(slider11:GetName() .. "Low"):SetText("0")
	getglobal(slider11:GetName() .. "High"):SetText("100")
	getglobal(slider11:GetName() .. "Text"):SetText(options.PlayerHealthThreshold.."%")
	slider11:SetPoint("TOPRIGHT", -10, y)
	y = y - lineStep

	-- Cloak of Shadows checkbox
	local fs = panel:CreateFontString("MutilateOptions_cofsCheck", "OVERLAY", "GameFontNormal")
	fs:SetText("Show Cloak of Shadows icon when you have debuffs")
	fs:SetPoint("TOPLEFT", 10, y)
	local cb = CreateFrame("CheckButton", "$parent_cb1", panel, "OptionsCheckButtonTemplate")
	cb:SetWidth(18)
	cb:SetHeight(18)
	cb:SetScript("OnClick", function() options.SuggestCloakOfShadows = not options.SuggestCloakOfShadows end)
	cb:SetPoint("TOPRIGHT", -10, y)
	cb:SetChecked(options.SuggestCloakOfShadows)
	y = y - lineStep

	-- Cloak of shadows slider
	local fs = panel:CreateFontString("MutilateOptions_cofsSlider", "OVERLAY", "GameFontNormal")
	fs:SetText("Only show Cloak of Shadows icon when a debuff has more duration than this")
	fs:SetPoint("TOPLEFT", 10, y)
	local slider = CreateFrame("Slider", "$parent_sCofs", panel, "OptionsSliderTemplate")
	slider:SetMinMaxValues(0, 60)
	slider:SetValue(options.MinDebuffDurationForCofs)
	slider:SetValueStep(1)
	slider:SetObeyStepOnDrag(true)
	slider:SetScript("OnValueChanged", function(self) options.MinDebuffDurationForCofs = self:GetValue(); getglobal(self:GetName() .. "Text"):SetText(self:GetValue().."s")  end)
	getglobal(slider:GetName() .. "Low"):SetText("0")
	getglobal(slider:GetName() .. "High"):SetText("60")
	getglobal(slider:GetName() .. "Text"):SetText(options.MinDebuffDurationForCofs.."s")
	slider:SetPoint("TOPRIGHT", -10, y)
	y = y - lineStep

	-- Exsanguinate trigger slider
	local fs = panel:CreateFontString("MutilateOptions_exTrigSlider", "OVERLAY", "GameFontNormal")
	fs:SetText("Subtlety Exsanguinate trigger level (Rupture equivalent seconds)")
	fs:SetPoint("TOPLEFT", 10, y)
	local slider = CreateFrame("Slider", "$parent_exTrig", panel, "OptionsSliderTemplate")
	slider:SetMinMaxValues(0, 50)
	slider:SetValue(options.ExsanguinateTrigger)
	slider:SetValueStep(1)
	slider:SetObeyStepOnDrag(true)
	slider:SetScript("OnValueChanged", function(self) options.ExsanguinateTrigger = self:GetValue(); getglobal(self:GetName() .. "Text"):SetText(self:GetValue().."s")  end)
	getglobal(slider:GetName() .. "Low"):SetText("0")
	getglobal(slider:GetName() .. "High"):SetText("50")
	getglobal(slider:GetName() .. "Text"):SetText(options.ExsanguinateTrigger.."s")
	slider:SetPoint("TOPRIGHT", -10, y)
	y = y - lineStep

	-- Voice prompts sound channel
	local fs = panel:CreateFontString("MutilateOptions_soundChannel", "OVERLAY", "GameFontNormal")
	fs:SetText("Sound channel for voice prompts (System>Sound for volume sliders)")
	fs:SetPoint("TOPLEFT", 10, y)
	local dd = CreateFrame("Frame", "$parent_dd1", panel, "UIDropDownMenuTemplate")
	UIDropDownMenu_SetWidth(dd, 120) -- Use in place of dd:SetWidth
	dd:SetPoint("TOPRIGHT", 0, y)
	UIDropDownMenu_Initialize(dd, ns.SoundChannelDropDown_Menu)
	UIDropDownMenu_SetText(dd, options.SoundChannel)
	ns.SoundChannelDropDownFrame = dd
	y = y - lineStep

	-- Voice lead slider
	local fs = panel:CreateFontString("MutilateOptions_VoiceLeadSlider", "OVERLAY", "GameFontNormal")
	fs:SetText("Start voice prompt this many seconds before spell due (if possible)")
	fs:SetPoint("TOPLEFT", 10, y)
	local slider = CreateFrame("Slider", "$parent_VoiceLead", panel, "OptionsSliderTemplate")
	slider:SetMinMaxValues(0, 2)
	slider:SetValue(options.VoiceLeadTime)
	slider:SetValueStep(2 / 100)
	slider:SetObeyStepOnDrag(true)
	slider:SetScript("OnValueChanged", function(self) options.VoiceLeadTime = floor(self:GetValue() * 100 + 0.5) / 100; getglobal(self:GetName() .. "Text"):SetText(options.VoiceLeadTime.."s")  end)
	getglobal(slider:GetName() .. "Low"):SetText("0")
	getglobal(slider:GetName() .. "High"):SetText("2")
	getglobal(slider:GetName() .. "Text"):SetText(options.VoiceLeadTime.."s")
	slider:SetPoint("TOPRIGHT", -10, y)
	y = y - lineStep

	-- Pretend inGrop checkbox.
	local cb = CreateFrame("CheckButton", "$parent_cb1", panel, "OptionsCheckButtonTemplate")
	cb:SetWidth(18)
	cb:SetHeight(18)
	cb:SetScript("OnClick", function() options.PretendInGroup = not options.PretendInGroup end)
	cb:SetPoint("TOPRIGHT", -10, y)
	cb:SetChecked(options.PretendInGroup)
	local fs = panel:CreateFontString("MutilateOptions_pretendInGroupCheck", "OVERLAY", "GameFontNormal")
	fs:SetText("Pretend I'm in a group")
	fs:SetPoint("TOPLEFT", 10, y)
	y = y - lineStep

	-- Diagnostic trace checkbox.
	local cb = CreateFrame("CheckButton", "$parent_cb1", panel, "OptionsCheckButtonTemplate")
	cb:SetWidth(18)
	cb:SetHeight(18)
	cb:SetScript("OnClick", function() options.ConsoleTrace = not options.ConsoleTrace end)
	cb:SetPoint("TOPRIGHT", -10, y)
	cb:SetChecked(options.ConsoleTrace)
	local fs = panel:CreateFontString("MutilateOptions_traceCheck", "OVERLAY", "GameFontNormal")
	fs:SetText("Output diagnostic state trace to the console")
	fs:SetPoint("TOPLEFT", 10, y)
	y = y - lineStep

	local cb = CreateFrame("EditBox", "$parent_cb1", panel, "InputBoxTemplate")
	cb:SetWidth(80)
	cb:SetHeight(18)
	--cb:SetScript("OnClick", function() options.ConsoleTrace = not options.ConsoleTrace end)
	cb:SetPoint("TOPRIGHT", -10, y)
	
	--cb:SetChecked(options.ConsoleTrace)
	--local fs = panel:CreateFontString("MutilateOptions_traceCheck", "OVERLAY", "GameFontNormal")
	--fs:SetText("Trinket 1")
	--fs:SetPoint("TOPLEFT", 10, y)
	--y = y - lineStep
--	options.TrinketOne = fs.GetText
	



	local fstring = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fstring:SetText("|cffA0A0A0Logic based on http://www.icy-veins.com/wow/class-guides")
	fstring:SetPoint("TOPLEFT", 10, y)
	y = y - lineStep

	local fstring = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fstring:SetText("|cffA0A0A0For requests or comments, leave a note at: http://www.curse.com/addons/wow/mutilate")
	fstring:SetPoint("TOPLEFT", 10, y)
	y = y - lineStep

	InterfaceOptions_AddCategory(panel);
end

function ns.GetLocked()
	return options.locked
end

function ns.ToggleLocked()
	if options.locked then
		options.locked = false
		ns.displayFrame:SetScript("OnMouseDown", function(self) self:StartMoving() end)
		ns.displayFrame:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
		ns.displayFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
		ns.displayFrame:SetBackdropColor(0, 0, 0, .4)
		ns.displayFrame:EnableMouse(true)
	else
		options.locked = true
		ns.displayFrame:SetScript("OnMouseDown", nil)
		ns.displayFrame:SetScript("OnMouseUp", nil)
		ns.displayFrame:SetScript("OnDragStop", nil)
		ns.displayFrame:SetBackdropColor(0, 0, 0, 0)
		ns.displayFrame:EnableMouse(false)
	end
end


function ns.Options(msg, editBox)

	if (msg == 'show') then
		ns.displayFrame:Show() 
	elseif (msg == 'hide') then
		ns.displayFrame:Hide() 
	elseif (msg == '') then
		InterfaceOptionsFrame_OpenToCategory(getglobal("MutilateOptions"))
	end
	
end
	
function ns.SetScale(num)
	options.scale = num
	ns.displayFrame:SetScale(options.scale)
end

function ns.shallowCopyOfTable(t)
 	local t2 = {}
  	for k, v in pairs(t) do
   	 	t2[k] = v
  	end
  	return t2
end

function ns.SoundChannelDropDown_OnClck(self, arg1, arg2, checked)
	options.SoundChannel = arg1
	UIDropDownMenu_SetText(ns.SoundChannelDropDownFrame, arg1)
end

function ns.AddSoundChannelDropDowRow(info, name)
	info.text = name
	info.arg1 = name
	info.checked = (name == options.SoundChannel)
	UIDropDownMenu_AddButton(info)
end

function ns.SoundChannelDropDown_Menu(frame, level, menuList)
	local info = UIDropDownMenu_CreateInfo()
	info.func = ns.SoundChannelDropDown_OnClck
	ns.AddSoundChannelDropDowRow(info, "Master")
	ns.AddSoundChannelDropDowRow(info, "SFX")
	ns.AddSoundChannelDropDowRow(info, "Music")
	ns.AddSoundChannelDropDowRow(info, "Ambience")
	ns.AddSoundChannelDropDowRow(info, "Dialog")
	ns.AddSoundChannelDropDowRow(info, "No sound")
end
