MultiMacro = LibStub("AceAddon-3.0"):NewAddon("MultiMacro", "AceConsole-3.0", "AceEvent-3.0")

local DEBUG = false

local options = {
  name = "MultiMacro",
  handler = MultiMacro,
  type = 'group',
  args = {
    enable = {
      type = 'toggle',
      order = 1,
      name = 'Enabled',
      width = 'double',
      desc = 'Enable or disable this addon.',
      get = function(info) return MultiMacro.db.profile.enabled end,
      set = function(info, val) if (val) then MultiMacro:Enable() else MultiMacro:Disable() end end,
    }
  }
}

local defaults = {
  profile = {
    enabled = true
  }
}

function MultiMacro:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("MultiMacroDB", defaults)
  local parent = LibStub("AceConfig-3.0"):RegisterOptionsTable("MultiMacro", options, {"MultiMacro", "al"})
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MultiMacro", "MultiMacro")
  profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
  LibStub("AceConfig-3.0"):RegisterOptionsTable("MultiMacro.profiles", profiles)
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MultiMacro.profiles", "Profiles", "MultiMacro")

  self.list = {}
end

function MultiMacro:OnEnable()
  self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
  self:RegisterEvent("SPELLS_CHANGED")

  self:RegisterEvent("UPDATE_MACROS")
  self:RegisterEvent("UNIT_SPELLCAST_START")
  self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  self.db.profile.enabled = true
end

function MultiMacro:OnDisable()
  self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  self:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
  self:UnregisterEvent("SPELLS_CHANGED")

  self:UnregisterEvent("UPDATE_MACROS")
  self:UnregisterEvent("UNIT_SPELLCAST_START")
  self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  self.db.profile.enabled = false
end

function MultiMacro:PLAYER_SPECIALIZATION_CHANGED(event, unit)
  if unit == "player" then
    self:UpdateList()
    self:UpdateMacros()
  end
end

function MultiMacro:PLAYER_ENTERING_WORLD()
  -- need to give the system some time when we enter (mainly our first login).
  -- soemtimes SetMacroSpell won't work unless we delay.
  __wait(1.0, function(self)
    self:UpdateList()
    self:UpdateMacros()
  end, self)
end

function MultiMacro:ACTIVE_TALENT_GROUP_CHANGED()
  self:UpdateList()
  self:UpdateMacros()
end

function MultiMacro:SPELLS_CHANGED(event)
  self:UpdateList()
  self:UpdateMacros()
end

function MultiMacro:UPDATE_MACROS(event, unit, arg3)
  self:UpdateList()
  self:UpdateMacros()
end

function MultiMacro:UNIT_SPELLCAST_START(event, unit)
  if unit ~= "player" then
    return
  end
  self:UpdateMacros()
end

function MultiMacro:UNIT_SPELLCAST_SUCCEEDED(event, unit)
  if unit ~= "player" then
    return
  end
  self:UpdateMacros()
end

local function GetAbilityData(ability)
    local slotId = tonumber(ability)

    if slotId then
        local itemId = GetInventoryItemID("player", slotId)
        if itemId then
            local itemName = GetItemInfo(itemId)
            return "item", itemId, itemName
        else
            return "unknown", nil, nil
        end
    else
		local spellInfo = C_Spell.GetSpellInfo(ability)
        local spellName, spellId

        if spellInfo then
            spellName = spellInfo.name
            spellId = spellInfo.spellID
        else
			local itemId = C_Item.GetItemIDForItemInfo(ability)
			local itemName = C_Item.GetItemNameByID(itemId)
			if itemId and itemName then
				return "item", itemId, itemName
			end
		end

        if spellId then
            return "spell", spellId, spellName
        end

        return "unknown", nil, ability
    end
end

local function ComputeMacroInfo(macro)
    local effectType = nil
    local effectId = nil
    local effectName = nil
    local target = nil

	local codeInfo = MultiMacroCodeInfo.Get(macro)
	local codeInfoLength = #codeInfo

	for i=1, codeInfoLength do
		local command = codeInfo[i]

		if command.Type == "showtooltip" or command.Type == "use" or command.Type == "cast" then
			local ability, tar = SecureCmdOptionParse(command.Body)

			if ability ~= nil then
				effectType, effectId, effectName = GetAbilityData(ability)

				-- skip spells or items that do not exist
				if effectType ~= "unknown" then
					target = tar
					break
				end
			end
		elseif command.Type == "castsequence" then
			local sequenceCode, tar = SecureCmdOptionParse(command.Body)

			if sequenceCode ~= nil then
				local _, item, spell = QueryCastSequence(sequenceCode)
				local ability = item or spell

				if ability ~= nil then
					effectType, effectId, effectName = GetAbilityData(ability)
					target = tar
					break
				end

				break
			end
		elseif command.Type == "stopmacro" then
			local shouldStop = SecureCmdOptionParse(command.Body)
			if shouldStop == "TRUE" then
				break
			end
		elseif command.Type == "petcommand" then
			local shouldRun = SecureCmdOptionParse(command.Body)
			if shouldRun == "TRUE" then
				effectType = "other"
				if command.Command == "dismiss" then
					effectName = "Dismiss Pet"
				end
				break
			end
		elseif command.Type == "equipset" then
			local setName = SecureCmdOptionParse(command.Body)
			if setName then
				effectType = "equipment set"
				effectName = setName
			end
		elseif command.Type == "click" then
			local buttonName = SecureCmdOptionParse(command.Body)
			if buttonName then
				effectType = "other"
				effectName = buttonName
			end
		end
	end

	if effectType == nil and codeInfoLength > 0 then
		if codeInfo[codeInfoLength].Type == "fallbackAbility" then
			local ability = codeInfo[codeInfoLength].Body
			effectType, effectId, effectName = GetAbilityData(ability)
		elseif codeInfo[codeInfoLength].Type == "fallbackSequence" then
			local ability = QueryCastSequence(codeInfo[codeInfoLength].Body)
			effectType, effectId, effectName = GetAbilityData(ability)
		elseif codeInfo[codeInfoLength].Type == "fallbackEquipmentSet" then
			effectType = "equipment set"
			effectName = codeInfo[codeInfoLength].Body
		elseif codeInfo[codeInfoLength].Type == "fallbackClick" then
			effectType = "other"
			effectName = codeInfo[codeInfoLength].Body
		end
	end

    return effectType, effectId, effectName, target
end

function MultiMacro:UpdateList()
  local group = GetActiveSpecGroup()
  MultiMacroCodeInfo.ClearAll()

  -- local start = debugprofilestop()

  for i=1,MAX_ACCOUNT_MACROS+MAX_CHARACTER_MACROS do
    local macroName, _, macroBody = GetMacroInfo(i)
	if macroBody ~= nil then
		local macroIndex = i
		local macro = { Id = macroIndex, Code = macroBody }
	    local effectType, effectId, effectName, target = ComputeMacroInfo(macro)
		--print (macro.Id, macro.Code)
		--print (macroName, effectName, effectType, GetMacroSpell(macroIndex), effectId)

		if effectType == "spell" then
            if GetMacroSpell(macroIndex) ~= effectId then
                if effectName then
					self.list[macroIndex] = { Name = effectName, Target = target, Type = effectType }
                    --SetMacroSpell(macroIndex, effectName, target)
                end
            end
        elseif effectType == "item" then
            if GetMacroItem(macroIndex) ~= effectId then
                if effectName then
					self.list[macroIndex] = { Name = effectName, Target = target, Type = effectType }
                    --SetMacroItem(macroIndex, effectName, target)
                end
            end
        else
            if GetMacroSpell(macroIndex) or GetMacroItem(macroIndex) then
				self.list[macroIndex] = { Name = "", Target = nil, Type = nil }
                --SetMacroSpell(macroIndex, "", nil)
            end
        end
	end
  end

  -- self:Print(format("myFunction executed in %f ms", debugprofilestop()-start))
end

function MultiMacro:UpdateMacros()
  for key,value in pairs(self.list) do
	if value.Type == "spell" then
		SetMacroSpell(key, value.Name, value.Target)
	elseif value.Type == "item" then
		SetMacroItem(key, value.Name, value.Target)
	else
		SetMacroSpell(key, "", nil)
	end
  end
end

-- util functions

local waitTable = {};
local waitFrame = nil;

function __wait(delay, func, ...)
  if(type(delay)~="number" or type(func)~="function") then
    return false;
  end
  if(waitFrame == nil) then
    waitFrame = CreateFrame("Frame","WaitFrame", UIParent);
    waitFrame:SetScript("onUpdate",function (self,elapse)
      local count = #waitTable;
      local i = 1;
      while(i<=count) do
        local waitRecord = tremove(waitTable,i);
        local d = tremove(waitRecord,1);
        local f = tremove(waitRecord,1);
        local p = tremove(waitRecord,1);
        if(d>elapse) then
          tinsert(waitTable,i,{d-elapse,f,p});
          i = i + 1;
        else
          count = count - 1;
          f(unpack(p));
        end
      end
    end);
  end
  tinsert(waitTable,{delay,func,{...}});
  return true;
end
