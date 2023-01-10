require "Window"
require "CombatFloater"
require "ICCommLib"
require "ICComm"
require "Sound"
local KatiaBuilderToolkit = {} 
local Batcher = Apollo.GetPackage("Module:KatiaBatcher-1.0").tPackage
local Utils = Apollo.GetPackage("Module:KatiaBuildUtils-1.0").tPackage
local SetManager = Apollo.GetPackage("Module:KatiaSetManager-1.0").tPackage
local DecorEditor = Apollo.GetPackage("Module:KatiaDecorEditor-1.0").tPackage
local DecorFinder = Apollo.GetPackage("Module:KatiaDecorFinder-1.0").tPackage
local PlotFinder = Apollo.GetPackage("Module:KatiaPlotFinder-1.0").tPackage

function KatiaBuilderToolkit:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    return o
end

function KatiaBuilderToolkit:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

function KatiaBuilderToolkit:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("KatiaBuilderToolkit.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	self.kbtVersion = 8.3
	self.donates = {
		["Entity"] = {
			[Unit.CodeEnumFaction.ExilesPlayer] = "Katia Managan",
			[Unit.CodeEnumFaction.DominionPlayer] = "Bizarro Katia",
		},
		["Jabbit"] = {
			[Unit.CodeEnumFaction.ExilesPlayer] = "Katia Managan",
			[Unit.CodeEnumFaction.DominionPlayer] = "Bizarro Katia",
		},
	}
	self.slots = {}
	self.options = {}
	self.shopresults = {}
	self.checklist = {}
	self.tCategoryItems = {}
	self.acknowledged = {}
	self.rpplots = {}
	self.players = {}
	self.playersSeen = 0
	self.soundtracks = {
		{file="1.wav", duration=23.262},
		{file="2.wav", duration=28.687},
		{file="3.wav", duration=23.493},
		{file="win.wav", duration=12.024},
	}
	self.npcNicknames = {}
	self.queuedCommands = {}

	-- Register handlers for events, slash commands, etc.
	Apollo.RegisterSlashCommand("katia", "OnKatiaBuilderToolkitOn", self)
	Apollo.RegisterSlashCommand("kbt", "OnKatiaBuilderToolkitOn", self)
	Apollo.RegisterSlashCommand("katiaset", "OnKatiaBuilderSet", self)
	Apollo.RegisterSlashCommand("katiadecor", "OnKatiaBuilderDecor", self)
	Apollo.RegisterSlashCommand("katiacolor", "OnKatiaBuilderColor", self)
	Apollo.RegisterSlashCommand("katiashop", "OnKatiaBuilderShop", self)
	Apollo.RegisterSlashCommand("katiainteract", "OnKatiaBuilderInteractables", self)
	Apollo.RegisterSlashCommand("katiacleaner", "OnKatiaBuilderCleaner", self)
	Apollo.RegisterSlashCommand("katiarp", "OnKatiaBuilderRP", self)
	Apollo.RegisterSlashCommand("krp", "OnKatiaBuilderRP", self)
	Apollo.RegisterSlashCommand("kcopy", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kpaste", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kclone", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kplace", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kcrate", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kcratelink", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kdiff", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kaverage", "ParseCommand", self)
	Apollo.RegisterSlashCommand("ktarget", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kltt", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kfixlinks", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kfixchairs", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kfixghosts", "ParseCommand", self)
	Apollo.RegisterSlashCommand("krevertskyiunderstandtherisk", "ParseCommand", self)
	Apollo.RegisterSlashCommand("visit", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kvisit", "ParseCommand", self)
	Apollo.RegisterSlashCommand("home", "ParseCommand", self)
	Apollo.RegisterSlashCommand("khome", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kadd", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kaddall", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kaddlinkedset", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kaudit", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kremove", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kreloc", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kplaceall", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kplacealllink", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kclear", "ParseCommand", self)
	Apollo.RegisterSlashCommand("klink", "ParseCommand", self)
	Apollo.RegisterSlashCommand("klocate", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kworld", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kobject", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kdrag", "ParseCommand", self)
	Apollo.RegisterSlashCommand("ktrap", "OnTrap", self)
	Apollo.RegisterSlashCommand("ksummon", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kget", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kfind", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kfindplot", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kround", "ParseCommand", self)
	Apollo.RegisterSlashCommand("ksnapshot", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kreconstruct", "ParseCommand", self)
	Apollo.RegisterSlashCommand("kplay", "PlaySound", self)
	Apollo.RegisterSlashCommand("kventriloquist", "Vent", self)
	Apollo.RegisterSlashCommand("kvent", "Vent", self)
	Apollo.RegisterSlashCommand("kv", "Vent", self)
	Apollo.RegisterSlashCommand("kpuppet", "Puppet", self)
	Apollo.RegisterSlashCommand("kp", "Puppet", self)

	Apollo.RegisterEventHandler("HousingMyResidenceDecorChanged", "OnDecorChange", self)
	Apollo.RegisterEventHandler("HousingFreePlaceDecorCancelled", "OnDecorCancel", self)
	Apollo.RegisterEventHandler("HousingFreePlaceDecorMoveBegin", "OnDecorMoveBegin", self)
	Apollo.RegisterEventHandler("HousingFreePlaceDecorMoveEnd", "OnDecorMoveEnd", self)
	Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
	Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)

	self.HousingAddon = Apollo.GetAddon("Housing")
	self.connectTimer = ApolloTimer.Create(1, true, "ConnectVer", self)
	self.connectTimer:Start()
	self.rpDecayTimer = ApolloTimer.Create(155, true, "RPDecay", self)
	self.rpDecayTimer:Start()
	self.rpReportTimer = ApolloTimer.Create(30 + math.random(120), false, "RPReport", self)
	self.rpReportTimer:Start()
	self.bNotified = false
	self.highestVer = self.kbtVersion
end

function KatiaBuilderToolkit:HookChat()
	if not self.chatAddon then
		self.chatAddon = Apollo.GetAddon("ChatLog")
		self.chatAddon.oldChatHandler = self.chatAddon.OnChatMessage
		self.chatAddon.kbtExceptions = {}
		self.chatAddon.OnChatMessage = function (root, chan, msg)
			if chan:GetType() == ChatSystemLib.ChatChannel_Say or chan:GetType() == ChatSystemLib.ChatChannel_Emote then
				if root.kbtExceptions[msg.strSender .. ":" .. msg.arMessageSegments[1].strText] then
					root.kbtExceptions[msg.strSender .. ":" .. msg.arMessageSegments[1].strText] = nil
				else
					root.oldChatHandler(root, chan, msg)
				end
			else
				root.oldChatHandler(root, chan, msg)
			end
		end
	end
end

function KatiaBuilderToolkit:PlaySound(strCmd, strArg)
	local ind = tonumber(strArg) or 1
	if self.playTimer ~= nil then
		self.playQueue = ind
	else
		self.playTimer = ApolloTimer.Create(self.soundtracks[ind].duration, false, "RePlay", self)
		Sound.PlayFile(self.soundtracks[ind].file)
	end
	self.verComm:SendMessage("sound " .. ind)
end

function KatiaBuilderToolkit:QueueCommand(command)
	table.insert(self.queuedCommands, command)
	if self.commandTimer then
		self.commandTimer:Stop()
	end
	self.commandTimer = ApolloTimer.Create(1, false, "RunCommands", self)
	self.commandTimer:Start()
end

function KatiaBuilderToolkit:RunCommands()
	for _, command in ipairs(self.queuedCommands) do
		ChatSystemLib.Command(command)
	end
	self.queuedCommands = {}
	if self.commandTimer then
		self.commandTimer:Stop()
		self.commandTimer = nil
	end
end

function KatiaBuilderToolkit:Vent(strCmd, strArg)
	if not self.verComm then return end
	local target = GameLib.GetPlayerUnit():GetTarget()
	if target == nil then
		self:FloatText("Target an npc to ventriloquist!")
		return
	end
	local tid = target:GetId()
	local msg = "vent " .. tid .. " " .. strArg
	if string.sub(strArg, 1, 2) == "((" and string.find(strArg, ")) ") then
		self.npcNicknames[tid] = string.sub(strArg, 3, string.find(strArg, ")) ") - 1)
		self:OnVersionReceived(nil, msg, GameLib.GetPlayerUnit():GetName())
		self.verComm:SendMessage(msg)
		self:QueueCommand("/s " .. strArg)
	else
		if self.npcNicknames[tid] then
			msg = "vent " .. tid .. " ((" .. self.npcNicknames[tid] .. ")) " .. strArg
			self:OnVersionReceived(nil, msg, GameLib.GetPlayerUnit():GetName())
			self.verComm:SendMessage(msg)
			self:QueueCommand("/s ((" .. self.npcNicknames[tid] .. ")) " .. strArg)
		else
			self:OnVersionReceived(nil, msg, GameLib.GetPlayerUnit():GetName())
			self.verComm:SendMessage(msg)
			self:QueueCommand("/s ((" .. target:GetName() .. ")) " .. strArg)
		end
	end
end

function KatiaBuilderToolkit:Puppet(strCmd, strArg)
	if not self.verComm then return end
	local target = GameLib.GetPlayerUnit():GetTarget()
	if target == nil then
		self:FloatText("Target an npc to ventriloquist!")
		return
	end
	local tid = target:GetId()
	local msg = "puppet " .. tid .. " " .. strArg
	if string.sub(strArg, 1, 2) == "((" and string.find(strArg, ")) ") then
		self.npcNicknames[tid] = string.sub(strArg, 3, string.find(strArg, ")) ") - 1)
		self:OnVersionReceived(nil, msg, GameLib.GetPlayerUnit():GetName())
		self.verComm:SendMessage(msg)
		self:QueueCommand("/e " .. strArg)
	else
		if self.npcNicknames[tid] then
			msg = "puppet " .. tid .. " ((" .. self.npcNicknames[tid] .. ")) " .. strArg
			self:OnVersionReceived(nil, msg, GameLib.GetPlayerUnit():GetName())
			self.verComm:SendMessage(msg)
			self:QueueCommand("/e ((" .. self.npcNicknames[tid] .. ")) " .. strArg)
		else
			self:OnVersionReceived(nil, msg, GameLib.GetPlayerUnit():GetName())
			self.verComm:SendMessage(msg)
			self:QueueCommand("/e ((" .. target:GetName() .. ")) " .. strArg)
		end
	end
end

function KatiaBuilderToolkit:RePlay()
	if self.playQueue ~= nil then
		self.playTimer = ApolloTimer.Create(self.soundtracks[self.playQueue].duration, false, "RePlay", self)
		Sound.PlayFile(self.soundtracks[self.playQueue].file)
		self.playQueue = nil
	else
		self.playTimer = nil
	end
end

function KatiaBuilderToolkit:OnUnitCreated(unit)
	if unit ~= nil and unit:IsACharacter() and self.players[unit:GetName()] == nil then
		self.playersSeen = self.playersSeen + 1
		self.players[unit:GetName()] = 1
	end
end

function KatiaBuilderToolkit:OnUnitDestroyed(unit)
	if unit ~= nil and unit:IsACharacter() and self.players[unit:GetName()] ~= nil then
		self.playersSeen = self.playersSeen - 1
		self.players[unit:GetName()] = nil
	end
end

function KatiaBuilderToolkit:ConnectVer()
	if not self.verComm then
		self.verComm = ICCommLib.JoinChannel("KBTVersion", ICCommLib.CodeEnumICCommChannelType.Global);
		if self.verComm then
			self.verComm:SetReceivedMessageFunction("OnVersionReceived", self)
			self.verComm:SendMessage(tostring(self.kbtVersion))
		end
	elseif not self.rpmonComm then
		self.rpmonComm = ICCommLib.JoinChannel("KBTRPMon", ICCommLib.CodeEnumICCommChannelType.Global);
		if self.rpmonComm then
			self.rpmonComm:SetReceivedMessageFunction("OnRPMonReceived", self)
		end
	else
		self.connectTimer:Stop()
	end 
end

local function PlayerDistance(a, b)
	return math.sqrt((a.x - b.x) * (a.x - b.x) +
					(a.y - b.y) * (a.y - b.y) +
					(a.z - b.z) * (a.z - b.z))
end

function KatiaBuilderToolkit:OnVersionReceived(iccomm, strMessage, strSender)
	local seenVer = tonumber(strMessage)
	if seenVer then
		if seenVer > self.highestVer then
			self.highestVer = seenVer
			if not self.bNotified then
				self.wndMain:FindChild("Title"):SetText("UPDATE NEEDED")
				self.wndMain:FindChild("Title"):SetTextColor({r=1,b=0,g=0,a=1})
				self.bNotified = true
			end
		end
	elseif strMessage == "request" then
		self.verComm:SendPrivateMessage(strSender, "running version " .. tostring(self.kbtVersion) .. " reporting: " .. tostring(self.bReporter))
	elseif strMessage == "showerrors" then
		local errors = Apollo.GetAddonInfo("KatiaBuilderToolkit").arErrors
		if errors ~= nil then
			for _, e in pairs(errors) do
				self.verComm:SendPrivateMessage(strSender, e)
			end
		end
	elseif string.sub(strMessage, 1, 5) == "vent " and 
		(strSender == "Katia Managan" or (HousingLib.GetResidence() and HousingLib.GetResidence():GetPropertyOwnerName() == strSender)) then
		local args = string.sub(strMessage, 6, -1)
		local spaceInd = string.find(args, " ")
		if spaceInd ~= nil and spaceInd > 1 then
			local id = tonumber(string.sub(args, 1, spaceInd - 1))
			local message = string.sub(args, spaceInd + 1)
			if id ~= nil then
				local unit = GameLib.GetUnitById(id)
				if unit ~= nil and not unit:IsACharacter() and 
					PlayerDistance(unit:GetPosition(), GameLib.GetPlayerUnit():GetPosition()) < 30 then
					local dialogue
					local npc
					
					if string.sub(message, 1, 2) == "((" and string.find(message, ")) ") then
						local talkIndex = string.find(message, ")) ")
						dialogue = string.sub(message, talkIndex + 3)
						npc = string.sub(message, 3, talkIndex - 1)
					else
						dialogue = message
						npc = unit:GetName()
					end
					
					unit:AddTextBubble(dialogue)
					ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Say,
						dialogue, "((" .. npc .. "))")
					self:HookChat()
					self.chatAddon.kbtExceptions[strSender .. ":((" .. npc .. ")) " .. dialogue] = true
				end
			end
		end
	elseif string.sub(strMessage, 1, 7) == "puppet " and 
		(strSender == "Katia Managan" or (HousingLib.GetResidence() and HousingLib.GetResidence():GetPropertyOwnerName() == strSender)) then
		local args = string.sub(strMessage, 8, -1)
		local spaceInd = string.find(args, " ")
		if spaceInd ~= nil and spaceInd > 1 then
			local id = tonumber(string.sub(args, 1, spaceInd - 1))
			local message = string.sub(args, spaceInd + 1)
			if id ~= nil then
				local unit = GameLib.GetUnitById(id)
				if unit ~= nil and not unit:IsACharacter() and 
					PlayerDistance(unit:GetPosition(), GameLib.GetPlayerUnit():GetPosition()) < 30 then
					local dialogue
					local npc
					
					if string.sub(message, 1, 2) == "((" and string.find(message, ")) ") then
						local talkIndex = string.find(message, ")) ")
						dialogue = string.sub(message, talkIndex + 3)
						npc = string.sub(message, 3, talkIndex - 1)
					else
						dialogue = message
						npc = unit:GetName()
					end
					
					ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Emote,
						dialogue, "((" .. npc .. "))")
					self:HookChat()
					self.chatAddon.kbtExceptions[strSender .. ":((" .. npc .. ")) " .. dialogue] = true
				end
			end
		end
	elseif string.sub(strMessage, 1, 6) == "sound " then
		local res = HousingLib.GetResidence()
		if res == nil then return end
		if res:GetPropertyOwnerName() ~= strSender then return end
		local ind = tonumber(string.sub(strMessage, 7)) or 1
		if self.playTimer ~= nil then
			self.playQueue = ind
		else
			self.playTimer = ApolloTimer.Create(self.soundtracks[ind].duration, false, "RePlay", self)
			Sound.PlayFile(self.soundtracks[ind].file)
		end
	elseif string.find(GameLib.GetPlayerUnit():GetName(), "Katia") ~= nil then -- Assuming nobody else wants to see this stuff:P
		Print(strSender .. ": " .. strMessage)
	end
end

function KatiaBuilderToolkit:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "KatiaBuilderToolkitForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndShop = Apollo.LoadForm(self.xmlDoc, "ShopForm", nil, self)
		if self.wndShop == nil then
			Apollo.AddAddonErrorText(self, "Could not load the shop window for some reason.")
			return
		end
		
	    self.wndCleaner = Apollo.LoadForm(self.xmlDoc, "CleanerForm", nil, self)
		if self.wndCleaner == nil then
			Apollo.AddAddonErrorText(self, "Could not load the crate cleaner window for some reason.")
			return
		end
		
	    self.wndInteract = Apollo.LoadForm(self.xmlDoc, "InteractForm", nil, self)
		if self.wndInteract == nil then
			Apollo.AddAddonErrorText(self, "Could not load the interactables window for some reason.")
			return
		end
		
	    self.wndRP = Apollo.LoadForm(self.xmlDoc, "RPForm", nil, self)
		if self.wndRP == nil then
			Apollo.AddAddonErrorText(self, "Could not load the RP window for some reason.")
			return
		end

	    self.wndRPAsk = Apollo.LoadForm(self.xmlDoc, "AskReport", nil, self)
		if self.wndRPAsk == nil then
			Apollo.AddAddonErrorText(self, "Could not load the RP report dialog for some reason.")
			return
		end
		
	    self.wndOptions = Apollo.LoadForm(self.xmlDoc, "OptionsForm", nil, self)
		if self.wndOptions == nil then
			Apollo.AddAddonErrorText(self, "Could not load the options window for some reason.")
			return
		end
		
	    self.wndDonate = Apollo.LoadForm(self.xmlDoc, "DonateForm", nil, self)
		if self.wndDonate == nil then
			Apollo.AddAddonErrorText(self, "Could not load the donation window for some reason.")
			return
		end
		
		self.wndMenu = Apollo.LoadForm(self.xmlDoc, "MenuForm", self.wndMain, self)
		if self.wndMenu == nil then
			Apollo.AddAddonErrorText(self, "Could not load the menu window for some reason.")
			return
		end
		
		self.wndBack = Apollo.LoadForm(self.xmlDoc, "Background", "InWorldHudStratum", self)
		if self.wndBack == nil then
			Apollo.AddAddonErrorText(self, "Could not load the background window for some reason.")
			return
		end
	

	    self.wndMain:Show(false, true)
	    self.wndShop:Show(false, true)
	    self.wndCleaner:Show(false, true)
	    self.wndInteract:Show(false, true)
	    self.wndRP:Show(false, true)
	    self.wndRPAsk:Show(false, true)
	    self.wndOptions:Show(false, true)
	    self.wndDonate:Show(false, true)
		self.wndMenu:Show(false, true)
		self.wndMain:FindChild("Position"):SetCheck(true)
		self.wndMain:FindChild("Rotation"):SetCheck(true)
		self.wndMain:FindChild("Scale"):SetCheck(true)
		self:ApplyOptions()
		
		self.interactTimer = ApolloTimer.Create(0.5, true, "OnInteractTick", self)
		self.interactTimer:Start()
	end
end


-----------------------------------------------------
-- Rotation bug fix
-----------------------------------------------------

function KatiaBuilderToolkit:OnDecorMoveBegin(dec)
	if HousingLib.GetResidence():GetCustomizationMode() == HousingLib.ResidenceCustomizationMode.Advanced then
		self.premove = Utils:DecorToPack(dec)
	end
end

function KatiaBuilderToolkit:OnDecorMoveEnd(dec)
	DecorEditor:Refresh()
	if self.premove == nil then
		return
	end

	local pack = Utils:DecorToPack(dec)
	-- If the move is a translation, make sure the scale and rotation don't change
	if math.abs(pack.X - self.premove.X) > .01 or
		math.abs(pack.Y - self.premove.Y) > .01 or
		math.abs(pack.Z - self.premove.Z) > .01 then
		dec:SetRotation(self.premove.P, self.premove.R, self.premove.Yaw)
		dec:SetScale(self.premove.S)
	end
	self.premove = nil
end


-----------------------------------------------------
-- Helper functions
-----------------------------------------------------

-- sorted iterator
local function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end

local function snext(t, state)
    key = nil
    if state == nil then
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
    else
        for i = 1,table.getn(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end

    if key then
        return key, t[key]
    end

    t.__orderedIndex = nil
    return
end

local function spairs(t)
    return snext, t, nil
end

-- Update slot selectors in UI
function Increment(window, label, amount)
	local value = tonumber(window:FindChild(label):GetText())
	if value == nil then
		self:FloatText("Not a number")
		return
	end
	window:FindChild(label):SetText(string.format("%d", value + amount))
end

function IncrementF(window, label, amount)
	local value = tonumber(window:FindChild(label):GetText())
	if value == nil then
		self:FloatText("Not a number")
		return
	end
	window:FindChild(label):SetText(string.format("%.2f", value + amount))
end

-- Display screen message to user
function KatiaBuilderToolkit:FloatText(strMessage)
	local tTextOption =	{
		strFontFace = "CRB_FloaterLarge",
		fDuration = 3.5,
		fScale = 1,
		fExpand = 1,
		fVibrate = 0,
		fSpinAroundRadius = 0,
		fFadeInDuration = 0.2,
		fFadeOutDuration = 0.5,
		fVelocityDirection = 0,
		fVelocityMagnitude = 0,
		fAccelDirection = 0,
		fAccelMagnitude = 0,
		fEndHoldDuration = 1,
		eLocation = CombatFloater.CodeEnumFloaterLocation.Bottom,
		fOffsetDirection = 0,
		fOffset = 0,
		eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Horizontal,
		fExpandCollisionBoxWidth = 1,
		fExpandCollisionBoxHeight = 1,
		nColor = 0xFF0000,
		iUseDigitSpriteSet = nil,
		bUseScreenPos = true,
		bShowOnTop = true,
		fRotation = 0,
		fDelay = 0,
		nDigitSpriteSpacing = 0,
	}
	
	CombatFloater.ShowTextFloater(GameLib.GetControlledUnit(), strMessage, tTextOption)
end

-- Check if all strings in matchers are in check
local function CheckMatchers(check, matchers)
	for _,i in pairs(matchers) do
		if string.find(string.lower(check), string.lower(i)) == nil then
			return false
		end
	end
	return true
end


-----------------------------------------------------
-- Slash commands
-----------------------------------------------------

-- /katia
function KatiaBuilderToolkit:OnKatiaBuilderToolkitOn()
	self.wndMain:Invoke() -- show the window
end

-- /katiaset
function KatiaBuilderToolkit:OnKatiaBuilderSet()
	SetManager:Open()
	self.wndMenu:Close() -- hide the menu if it was used to get here
end

-- /katiashop
function KatiaBuilderToolkit:OnKatiaBuilderShop()
	self.wndShop:Invoke() -- show the window
	self.wndMenu:Close() -- hide the menu if it was used to get here
	self:ShowShopResults()
end

function KatiaBuilderToolkit:OnKatiaBuilderOptions()
	self.wndOptions:Invoke() -- show the window
	self.wndMenu:Close() -- hide the menu if it was used to get here
end

function KatiaBuilderToolkit:OnKatiaBuilderDecor()
	DecorEditor:Open()
	self.wndMenu:Close() -- hide the menu if it was used to get here
end

function KatiaBuilderToolkit:OnShopScan()
	if not HousingLib.IsOnMyResidence() then
		self:FloatText("Please return to your home to scan")
		return
	end
	self.wndShop:Close()
	local todo = Batcher:Prepare(
		function (b, id)
			local dec = HousingLib.PreviewVendorDecor(id)
			if dec ~= nil and dec:GetName() ~= "" then
				table.insert(self.catalog, {I=id, N=dec:GetName(), T=dec:GetDecorType()})
				dec:CancelTransform()
				if id > self.highestKnownDecorID then
					self.highestKnownDecorID = id
				end
				--self:FloatText("LastAdded: "..b.lastAdded)
				if id + 1000 >= b.lastAdded then
					for i = b.lastAdded, id + 1010 do
						table.insert(b.todo, i)
					end
					b.lastAdded = id + 1010
					
					b.barProg:SetMax(b.lastAdded)
				end
			end
		end,
		nil,
		nil
	)
	if todo == nil then return end
	self.catalog = {}
	if self.highestKnownDecorID == nil or self.highestKnownDecorID < 4300 then
		self.highestKnownDecorID = 4300
	end
	Batcher.lastAdded = self.highestKnownDecorID + 1000
	for i=1,Batcher.lastAdded do
		table.insert(todo, i)
	end
	Batcher:StartTimed(0.03)
end

function KatiaBuilderToolkit:OnShopSearch()
	if self.catalog == nil then
		self:FloatText("Please scan the decor list first")
		return
	end
	self.shopresults = {}

	local terms = {}
	local rescan = true
	string.gsub(self.wndShop:FindChild("Terms"):GetText(),
				"([^ ]+)", function(c) table.insert(terms, c) end)
	for _, dec in pairs(self.catalog) do
		if CheckMatchers(dec.N, terms) and (dec.T == nil or self.shopfilter == nil or self.shopfilter[dec.T]) then
			table.insert(self.shopresults, dec)
		end
		if dec.T ~= nil then rescan = false end
	end
	if rescan then self:FloatText("Redo scan to enable search by category") end
	self.wndShop:FindChild("Page"):SetText("1")
	
	self:ShowShopResults()
end

function KatiaBuilderToolkit:OnSortByCheck()
	self:PopulateCategoryList()
	self.wndShop:FindChild("SortByWindow"):Show(true)
end

function KatiaBuilderToolkit:OnSortByUncheck()
	self.wndShop:FindChild("SortByWindow"):Show(false)
end

function KatiaBuilderToolkit:PopulateCategoryList()
	local wndSortByList = self.wndShop:FindChild("SortByList")
	local nScrollPosition = wndSortByList:GetVScrollPos()
	for _, item in pairs(self.tCategoryItems) do
		item:Destroy()
	end
	self.tCategoryItems = {}

    local tCategoryList = {}
	for _, dec in pairs(HousingLib.GetDecorTypeList()) do
		if dec.strName ~= nil and dec.strName ~= "" then
			if tCategoryList[dec.strName] == nil then
				tCategoryList[dec.strName] = {strName = dec.strName, nIds = {}}
			end
			tCategoryList[dec.strName].nIds[dec.nId] = true
		end
	end
	
	-- populate the list
    if tCategoryList ~= nil then
        local tFirstItemData = {}
        tFirstItemData.strName = Apollo.GetString("HousingDecorate_AllTypes")
        self:AddCategoryItem(wndSortByList, tFirstItemData)
        for _, item in spairs(tCategoryList) do
			self:AddCategoryItem(wndSortByList, item)
        end
    end
    
    self.tCategoryList = tCategoryList
	
	-- now all the iteam are added, call ArrangeChildrenVert to list out the list items vertically
	wndSortByList:ArrangeChildrenVert()
	wndSortByList:SetVScrollPos(nScrollPosition)
end

function KatiaBuilderToolkit:AddCategoryItem(wndSortByList, tItemData)
	local wndListItem = Apollo.LoadForm(self.xmlDoc, "CategoryListItem", wndSortByList, self)
	table.insert(self.tCategoryItems, wndListItem)
	local wndItemBtn = wndListItem:FindChild("CategoryBtn")
	if wndItemBtn then -- make sure the text wndListItem exist
	    local strName = tItemData.strName
		wndItemBtn:SetText(strName)
		wndItemBtn:SetData(tItemData)
	end
end

function KatiaBuilderToolkit:OnSortByItemSelected(wndHandler, wndControl)
	if not wndControl then 
        return 
    end

	local tData = wndControl:GetData()
	self.shopfilter = tData.nIds
	self.wndShop:FindChild("SortByBtn"):SetText(tData.strName)
	self.wndShop:FindChild("SortByBtn"):SetCheck(false)
	self:OnSortByUncheck()
end

function KatiaBuilderToolkit:Acknowledge()
	local tDecorVendorList = HousingLib.GetDecorCatalogList()
	if tDecorVendorList ~= nil then
		self.acknowledged = {}
		for idx = 1, #tDecorVendorList do
			local tVendorDecorData = tDecorVendorList[idx]
			self.acknowledged[tVendorDecorData.nId] = true
		end
	end
	self:ShowNewVendor()
end

function KatiaBuilderToolkit:ShowNewVendor()
	self.shopresults = {}
	local tDecorVendorList = HousingLib.GetDecorCatalogList()
	if tDecorVendorList ~= nil then
		for idx = 1, #tDecorVendorList do
			local tVendorDecorData = tDecorVendorList[idx]
			if not self.acknowledged[tVendorDecorData.nId] then
				table.insert(self.shopresults, {I = tVendorDecorData.nId, N = tVendorDecorData.strName, T = tVendorDecorData.eDecorType})
			end
		end
	end
	self.wndShop:FindChild("Page"):SetText("1")
	self:ShowShopResults()
end

function KatiaBuilderToolkit:ShowShopResults()
	local maxresults = tonumber(self.wndShop:FindChild("MaxResults"):GetText())
	if maxresults == nil then maxresults = 50 end
	self.wndShop:FindChild("MaxResults"):SetText(tostring(maxresults))
	local start = (tonumber(self.wndShop:FindChild("Page"):GetText()) - 1) * maxresults + 1
	local finish = start + maxresults - 1
	local pages = math.floor((#self.shopresults + maxresults - 1) / maxresults)
	self.wndShop:FindChild("PageMax"):SetText(tostring(pages))

	local wndList = self.wndShop:FindChild("List")
	wndList:DestroyChildren()
	for i=start,finish,1 do
		local dec = self.shopresults[i]
		if dec ~= nil then
			local wndListItem = Apollo.LoadForm(self.xmlDoc, "ShopItem", wndList, self)
			wndListItem:SetData(dec)
			local wndMod = wndListItem:FindChild("ModelWindow")
			wndMod:SetDecorInfo(dec.I)
			local wndName = wndListItem:FindChild("Name")
			wndName:SetText(dec.N)
		end
	end
	wndList:ArrangeChildrenTiles()
end

function KatiaBuilderToolkit:OnShopSelect(wndHandler, wndControl, eMouseButton)
	local dec = wndHandler:GetData()
	self.wndShop:FindChild("SelectedName"):SetText(dec.N)
	self.wndShop:FindChild("SelectedId"):SetText(dec.I)
	self.wndShop:FindChild("SelectedJabbit"):SetText("www.jabbithole.com/search?q=" .. string.gsub(dec.N, " ", "+"))
	self.wndShop:FindChild("SelectedModel"):SetDecorInfo(dec.I)
	self.shopDecorID = dec.I
end

function KatiaBuilderToolkit:OnShopAddToCrate( wndHandler, wndControl, eMouseButton )
	if self.shopDecorID ~= nil then
		local sendCommand = string.format("!house decoradd %s 1", self.shopDecorID)
		ChatSystemLib.Command(sendCommand)
	end
end

function KatiaBuilderToolkit:OnShopSearchAH()
	local wndAuc = Apollo.GetAddon("MarketplaceAuction").wndMain
	if wndAuc == nil or not wndAuc:IsShown() then
		self:FloatText("Please open the auction house")
		return
	end
	wndAuc:ToFront()
	local searches = {}
	for _, dat in pairs(MarketplaceLib.SearchAuctionableItems(self.wndShop:FindChild("SelectedName"):GetText())) do
		table.insert(searches, dat.nId or 0)
	end
	MarketplaceLib.RequestItemAuctionsByItems(searches, 0, MarketplaceLib.AuctionSort.Buyout, false, {}, false, false)
end

-- /kfindplot
function KatiaBuilderToolkit:FindPlot(strArg)
	if strArg == "" then
		PlotFinder:OnFindPlot()
		return
	end
	local terms = {}
	string.gsub(strArg, "([^ ]+)", function(c) table.insert(terms, c) end)
	local tries = tonumber(terms[1])
	if tries ~= nil then
		table.remove(terms, 1)
	end

	PlotFinder:ScanPlots(tries, terms)
end

function ToHundredth(num)
	return math.floor(num * 100 + .5) / 100
end

-- /ktrap easter egg :)
function KatiaBuilderToolkit:OnTrap()
	local target = GameLib.GetPlayerUnit():GetTarget()
	if target == nil then
		self:FloatText("Target a victim!")
		return
	end
	local tPos = target:GetPosition()
	local dPos = Utils:PlayerToDecorPos(tPos)
	dPos.Y = dPos.Y + 8
	dPos.P = 180
	dPos.R = 0
	dPos.Yaw = 0
	dPos.S = .8
	dPos.N = "Coffin (Spiked)"
	Utils:ClonePack(dPos)
	Utils:Place()
end


-----------------------------------------------------
-- Rest of the slash commands
-----------------------------------------------------

function KatiaBuilderToolkit:ParseCommand(strCmd, strArg)
	if strCmd == "kcopy" then
		if tonumber(strArg) == nil then
			self:OnCopy()
		else
			self:Copy(tonumber(strArg))
		end
	elseif strCmd == "kpaste" then
		if tonumber(strArg) == nil then
			self:OnPaste()
		else
			self:Paste(tonumber(strArg))
		end
	elseif strCmd == "kclone" then
		if tonumber(strArg) == nil then
			self:OnClone()
		else
			self:Clone(tonumber(strArg))
		end
	elseif strCmd == "kplace" then
		Utils:Place()
	elseif strCmd == "kcrate" then
		Utils:Crate()
	elseif strCmd == "kcratelink" then
		Utils:CrateLinkedSet()
	elseif strCmd == "kdiff" then
		if strArg == "" then
			self:OnDiff()
		else
			local x, y = string.find(strArg, " ")
			if x == nil or y == nil then
				self:FloatText("Must specify from and to")
				return
			end
			self:Diff(tonumber(string.sub(strArg, 1, x - 1)), tonumber(string.sub(strArg, x + 1, -1)))
		end
	elseif strCmd == "kaverage" then
		if strArg == "" then
			self:OnAverage()
		else
			local x, y = string.find(strArg, " ")
			if x == nil or y == nil then
				self:FloatText("Must specify from and to")
				return
			end
			self:Average(tonumber(string.sub(strArg, 1, x - 1)), tonumber(string.sub(strArg, x + 1, -1)))
		end
	elseif strCmd == "ktarget" then
		self:Target()
	elseif strCmd == "kltt" then
		DecorEditor:LinkToTarget()
	elseif strCmd == "kfixlinks" then
		self:FixLinks()
	elseif strCmd == "kfixchairs" then
		self:FixChairs()
	elseif strCmd == "kfixghosts" then
		self:FixGhosts()
	elseif strCmd == "krevertskyiunderstandtherisk" then
		self:RevertSky()
	elseif strCmd == "visit" or strCmd == "kvisit" then
		self:Visit(strArg)
	elseif strCmd == "home" or strCmd == "khome" then
		self:Visit(GameLib.GetPlayerUnit():GetName())
	elseif strCmd == "kadd" then
		SetManager:Add()
	elseif strCmd == "kaddlinkedSet" then
		if tonumber(strArg) == nil then
			SetManager:OnAddLinkedSet()
		else
			SetManager:AddLinkedSet(tonumber(strArg))
		end
	elseif strCmd == "kaddall" then
		SetManager:AddAll()
	elseif strCmd == "kremove" then
		SetManager:Remove()
	elseif strCmd == "kclear" then
		if tonumber(strArg) == nil then
			SetManager:OnClear()
		else
			SetManager:Clear(tonumber(strArg))
		end
	elseif strCmd == "kaudit" then
		if tonumber(strArg) == nil then
			SetManager:OnAudit()
		else
			SetManager:Audit(tonumber(strArg))
		end
	elseif strCmd == "kreloc" then
		SetManager:Reloc()
	elseif strCmd == "kplaceall" then
		SetManager:PlaceAll(false)
	elseif strCmd == "kplacealllink" then
		SetManager:PlaceAll(true)
	elseif strCmd == "klink" then
		DecorEditor:OnLink()
	elseif strCmd == "klocate" then
		Utils:Locate()
	elseif strCmd == "kworld" then
		DecorEditor:OnWorld()
	elseif strCmd == "kobject" then
		DecorEditor:OnObject()
	elseif strCmd == "kdrag" then
		DecorEditor:OnDrag()
	elseif strCmd == "ksummon" then
		Utils:Summon(strArg)
	elseif strCmd == "kget" then
		Utils:Summon(strArg)
	elseif strCmd == "kfind" then
		DecorFinder:Find(strArg)
	elseif strCmd == "kfindplot" then
		self:FindPlot(strArg)
	elseif strCmd == "kround" then
		Utils:Round()
	elseif strCmd == "ksnapshot" then
		self:Snapshot()
	elseif strCmd == "kreconstruct" then
		self:Reconstruct()
	end
end


function KatiaBuilderToolkit:Visit(destination)
	if self.rpplots ~= nil and self.rpplots[destination] ~= nil and self.rpplots[destination][4] == "closed" and ((self.rpplots[destination][1] == "Dominion" and GameLib.GetPlayerBaseFaction() == 167) or (self.rpplots[destination][1] == "Exile" and GameLib.GetPlayerBaseFaction() == 166)) then
		self:FloatText("That plot is not open to cross-faction RP")
		return
	end
	HousingLib.RequestVisitPlayer(destination)
end


-----------------------------------------------------
-- Utility functions for housing manipulation
-----------------------------------------------------

function DecorIdToName(id)
	local dec = HousingLib.PreviewVendorDecor(id)
	local name = ""
	if dec ~= nil then
		name = dec:GetName()
		dec:CancelTransform()
	end
	return name
end

function KatiaBuilderToolkit:DecorNameToId(name, from, to)
	for i=from,to do
		local dec = HousingLib.PreviewVendorDecor(i)
		if dec ~= nil and dec:GetName() == name then
			dec:CancelTransform()
			return i
		end
		dec:CancelTransform()
	end
end

function KatiaBuilderToolkit:CopyPack()
	local sDecor = HousingLib.GetResidence():GetSelectedDecor()
	if sDecor == nil then
		self:FloatText("No decor selected")
		return nil
	end
	return Utils:DecorToPack(sDecor)
end

-----------------------------------------------------
-- Watcher for decor updates
-----------------------------------------------------

function KatiaBuilderToolkit:OnDecorCancel(decor)
	if decor ~= nil and self.wndMain:FindChild("AutoLink"):IsChecked() and self.targetedId ~= nil and not decor:IsChild() then
		local targeted = HousingLib.GetResidence():GetDecorById(self.targetedId, self.targetedIdHigh)
		if targeted ~= nil then
			decor:Link(targeted)
		end
	end
end	

function KatiaBuilderToolkit:OnDecorChange(decor)
	if self.wndMain == nil then return end

	if decor ~= nil and self.wndMain:FindChild("AutoLink"):IsChecked() and self.targetedId ~= nil and not decor:IsChild() then
		local targeted = HousingLib.GetResidence():GetDecorById(self.targetedId, self.targetedIdHigh)
		if targeted ~= nil then
			decor:Link(targeted)
		end
	elseif self.bSelectNew then
		decor:Select()
		self.bSelectNew = nil
	end
end


function intnumcomparator(a,b)
	if type(a) ~= type(b) then
		return type(a) < type(b)
	end
	return a < b
end


function KatiaBuilderToolkit:OnDonate()
	self.wndDonate:Invoke()
	self.wndMenu:Close() -- hide the menu if it was used to get here
	self:OnUpdateDonate()
end

function KatiaBuilderToolkit:OnCancelDonate()
	self.wndDonate:Close()
end

function KatiaBuilderToolkit:ThankDonator()
	self:FloatText("Thanks for your donation! <3")
end

function KatiaBuilderToolkit:OnUpdateDonate()
	local realmSet = self.donates[GameLib.GetRealmName()]
	local donatee
	if realmSet ~= nil then
		local player = GameLib.GetPlayerUnit()
		if player ~= nil then
			donatee = realmSet[player:GetFaction()]
		end
	end
	if donatee then
		local message = self.wndDonate:FindChild("Message"):GetText()
		self.wndDonate:FindChild("CashWindow"):SetAmount(10000)
		self.wndDonate:FindChild("Send1G"):Enable(true)
		self.wndDonate:FindChild("Send1G"):SetActionData(GameLib.CodeEnumConfirmButtonType.SendMail, donatee, GameLib.GetRealmName(), "KBT donation! (1G)", message, {}, MailSystemLib.MailDeliverySpeed_Instant, 0, self.wndDonate:FindChild("CashWindow"):GetCurrency())
		self.wndDonate:FindChild("CashWindow"):SetAmount(100000)
		self.wndDonate:FindChild("Send10G"):Enable(true)
		self.wndDonate:FindChild("Send10G"):SetActionData(GameLib.CodeEnumConfirmButtonType.SendMail, donatee, GameLib.GetRealmName(), "KBT donation! (10G)", message, {}, MailSystemLib.MailDeliverySpeed_Instant, 0, self.wndDonate:FindChild("CashWindow"):GetCurrency())
		self.wndDonate:FindChild("CashWindow"):SetAmount(1000000)
		self.wndDonate:FindChild("Send1P"):Enable(true)
		self.wndDonate:FindChild("Send1P"):SetActionData(GameLib.CodeEnumConfirmButtonType.SendMail, donatee, GameLib.GetRealmName(), "KBT donation! (1P)", message, {}, MailSystemLib.MailDeliverySpeed_Instant, 0, self.wndDonate:FindChild("CashWindow"):GetCurrency())
		self.wndDonate:FindChild("CashWindow"):SetAmount(10000000)
		self.wndDonate:FindChild("Send10P"):Enable(true)
		self.wndDonate:FindChild("Send10P"):SetActionData(GameLib.CodeEnumConfirmButtonType.SendMail, donatee, GameLib.GetRealmName(), "KBT donation! (10P)", message, {}, MailSystemLib.MailDeliverySpeed_Instant, 0, self.wndDonate:FindChild("CashWindow"):GetCurrency())
	else
		self.wndDonate:FindChild("Send1G"):Enable(false)
		self.wndDonate:FindChild("Send10G"):Enable(false)
		self.wndDonate:FindChild("Send1P"):Enable(false)
	end
end

-----------------------------------------------------
-- Toolkit functions
-----------------------------------------------------

function KatiaBuilderToolkit:Copy(slot)
	self.slots[slot] = self:CopyPack()
end

function KatiaBuilderToolkit:Paste(slot)
	local info = self.slots[slot]
	if info == nil then
		self:FloatText(string.format("Nothing copied in slot %s", slot))
		return
	end
	
	local selDecor = HousingLib.GetResidence():GetSelectedDecor()
	if selDecor == nil then
		self:FloatText("No decor selected")
		return
	end
	
	if self.wndMain:FindChild("Position"):IsChecked() then
		selDecor:SetPosition(info.X, info.Y, info.Z)
	end

	if self.wndMain:FindChild("Rotation"):IsChecked() then
		selDecor:SetRotation(info.P, info.R, info.Yaw)
	end
	
	if self.wndMain:FindChild("Scale"):IsChecked() then
		selDecor:SetScale(info.S)
	end
end

function KatiaBuilderToolkit:Clone(slot)
	local info = self.slots[slot]
	if info == nil then
		self:FloatText(string.format("Nothing copied in slot %s", slot))
		return
	end
	Utils:ClonePack(info, Apollo.IsShiftKeyDown())
	DecorEditor:Refresh()
end

function KatiaBuilderToolkit:Snapshot()
	local everything = HousingLib.GetResidence():GetPlacedDecorList()
	self.savedSnapshot = {}
	for i, dec in pairs(everything) do
		local pack = Utils:DecorToPack(dec)
		pack.low, pack.high = dec:GetId()
		table.insert(self.savedSnapshot, pack)
	end
end

function KatiaBuilderToolkit:Reconstruct()
	local todo = Batcher:Prepare(
		function (_, ch)
			local dec = HousingLib.PreviewCrateDecorAtLocation(ch.low, ch.high,
									ch.X, ch.Y, ch.Z,
									ch.P, ch.R, ch.Yaw,
									ch.S)
			local tDecorInfo = dec:GetDecorIconInfo()
			if tDecorInfo == nil then
				Print(ch.X .. " " .. ch.Y .. " " .. ch.Z .. " " .. ch.N .. " " .. ch.low .. " " .. ch.high)
				Batcher:ProcessTodo()
				return
			end
			local newX = tDecorInfo.fWorldPosX
			local newY = tDecorInfo.fWorldPosY
			local newZ = tDecorInfo.fWorldPosZ
			-- Deshift if necessary
			dec = HousingLib.PreviewCrateDecorAtLocation(
						ch.low,
						ch.high,
						2*ch.X - newX, 2*ch.Y - newY, 2*ch.Z  - newZ,
						ch.P, ch.R, ch.Yaw,
						ch.S)
			if dec ~= nil then
				-- Check if anything is in the way
				if not dec:ValidatePlacement() then
					dec:CancelTransform()
					Batcher:ProcessTodo()
				else
					dec:Place()
				end
			end
		end,
		nil,
		nil
	)
	if todo == nil then return end
	for _, pack in pairs(self.savedSnapshot) do
		local dec = HousingLib.GetResidence():GetDecorById(pack.low, pack.high)
		if dec ~= nil and dec:IsPreview() then
			table.insert(todo, pack)
		end
	end

	Batcher:StartDecorDriven()
end

function KatiaBuilderToolkit:Diff(fromslot, toslot)
	local frominfo = self.slots[fromslot]
	if frominfo == nil then
		self:FloatText(string.format("Nothing copied in slot %s", fromslot))
		return
	end
	local toinfo = self.slots[toslot]
	if toinfo == nil then
		self:FloatText(string.format("Nothing copied in slot %s", toslot))
		return
	end

	local oldSelection = HousingLib.GetResidence():GetSelectedDecor()
	local targeted = HousingLib.GetResidence():GetDecorById(self.targetedId, self.targetedIdHigh)
	if self.targetedId ~= nil and self.targetedIdHigh ~= nil and targeted ~= nil then
		targeted:Select()
	end
	
	local selDecor = HousingLib.GetResidence():GetSelectedDecor()
	if selDecor == nil then
		self:FloatText("No decor selected")
		return
	end
	
	local tDecorInfo = selDecor:GetDecorIconInfo()
	selDecor:SetPosition(tDecorInfo.fWorldPosX + toinfo.X - frominfo.X,
							tDecorInfo.fWorldPosY + toinfo.Y - frominfo.Y,
							tDecorInfo.fWorldPosZ + toinfo.Z - frominfo.Z)
	selDecor:SetRotation(tDecorInfo.fPitch + toinfo.P - frominfo.P,
							tDecorInfo.fRoll + toinfo.R - frominfo.R,
							tDecorInfo.fYaw + toinfo.Yaw - frominfo.Yaw)
	selDecor:SetScale(tDecorInfo.fScaleCurrent * toinfo.S / frominfo.S)
	if self.targetedId ~= nil and self.targetedIdHigh ~= nil then
		selDecor:Place()
		if oldSelection ~= nil then
			oldSelection:Select()
		end
	end
end

function KatiaBuilderToolkit:Average(fromslot, toslot)
	local frominfo = self.slots[fromslot]
	if frominfo == nil then
		self:FloatText(string.format("Nothing copied in slot %s", fromslot))
		return
	end
	local toinfo = self.slots[toslot]
	if toinfo == nil then
		self:FloatText(string.format("Nothing copied in slot %s", toslot))
		return
	end
	
	local oldSelection = HousingLib.GetResidence():GetSelectedDecor()
	local targeted = HousingLib.GetResidence():GetDecorById(self.targetedId, self.targetedIdHigh)
	if self.targetedId ~= nil and self.targetedIdHigh ~= nil and targeted ~= nil then
		targeted:Select()
	end
	
	local selDecor = HousingLib.GetResidence():GetSelectedDecor()
	if selDecor == nil then
		self:FloatText("No decor selected")
		return
	end
	
	local tDecorInfo = selDecor:GetDecorIconInfo()
	selDecor:SetPosition((toinfo.X + frominfo.X) / 2,
							(toinfo.Y + frominfo.Y) / 2,
							(toinfo.Z + frominfo.Z) / 2)
	selDecor:SetRotation((toinfo.P + frominfo.P) / 2,
							(toinfo.R + frominfo.R) / 2,
							(toinfo.Yaw + frominfo.Yaw) / 2)
	selDecor:SetScale((toinfo.S + frominfo.S) / 2)
	if self.targetedId ~= nil and self.targetedIdHigh ~= nil then
		selDecor:Place()
		if oldSelection ~= nil then
			oldSelection:Select()
		end
	end
end

function KatiaBuilderToolkit:Target()
	if self.targetedId ~= nil then
		self.targetedId = nil
		self.targetedIdHigh = nil
		self.wndMain:FindChild("Target"):SetBGColor({a=1,r=1,b=1,g=1})
		self.wndMain:FindChild("Diff"):SetBGColor({a=1,r=1,b=1,g=1})
		self.wndMain:FindChild("Average"):SetBGColor({a=1,r=1,b=1,g=1})
		self.wndMain:FindChild("Target"):SetText("Target")
		DecorEditor:Target(nil)
		DecorFinder:Target(nil)
		return
	end
	local selDecor = HousingLib.GetResidence():GetSelectedDecor()
	if selDecor == nil or selDecor:IsPreview() then
		self:FloatText("Must target a decor that is already placed.")
	else
		self.targetedId, self.targetedIdHigh = selDecor:GetId()
		self.wndMain:FindChild("Target"):SetBGColor({a=1,r=0,b=1,g=0})
		self.wndMain:FindChild("Diff"):SetBGColor({a=1,r=0,b=1,g=0})
		self.wndMain:FindChild("Average"):SetBGColor({a=1,r=0,b=1,g=0})
		self.wndMain:FindChild("Target"):SetText(selDecor:GetName())
		DecorEditor:Target(self.targetedId, self.targetedIdHigh)
		DecorFinder:Target(self.targetedId, self.targetedIdHigh)
	end
end

function KatiaBuilderToolkit:FixLinks()
	HousingLib.SetEditMode(true)
	for idx, dec in pairs(HousingLib.GetResidence():GetPlacedDecorList()) do
		local parents = {}
		parents[dec:GetHandle()] = true
		local cur = dec:GetParent()
		while cur ~= nil do
			if parents[cur:GetHandle()] then
				cur:Unlink()
				break
			end
			parents[cur:GetHandle()] = true
			cur = cur:GetParent()
		end
	end
	HousingLib.SetEditMode(false)
end

-- Chair bug is fixed by picking up and putting down in place
function KatiaBuilderToolkit:FixChairs()
	HousingLib.SetEditMode(true)
	local todo = Batcher:Prepare(
		function (_, id)
			local dec = HousingLib.GetResidence():GetDecorById(id.low, id.high)
			if dec ~= nil then
				dec:Select()
				local tDecorInfo = dec:GetDecorIconInfo()
				dec:SetPosition(tDecorInfo.fWorldPosX, tDecorInfo.fWorldPosY, tDecorInfo.fWorldPosZ)
				if not dec:ValidatePlacement() then
					dec:CancelTransform()
				else
					dec:Place()
				end
			end
		end,
		nil,
		nil
	)
	if todo == nil then return end

	for idx, dec in pairs(HousingLib.GetResidence():GetPlacedDecorList()) do
		if dec:IsChair() then
			table.insert(todo, {})
			todo[#todo].low, todo[#todo].high = dec:GetId()
		end
	end

	Batcher:StartTimed(0.15)
end

-- Settle everything in crate
function KatiaBuilderToolkit:FixGhosts()
	HousingLib.SetEditMode(true)
	local tDecorCrateList = HousingLib.GetResidence():GetDecorCrateList()
	if tDecorCrateList ~= nil then
		local todo = Batcher:Prepare(
			function (_, id)
				local dec = HousingLib.PreviewCrateDecorAtLocation(id.low, id.high)
				if dec ~= nil then
					dec:CancelTransform()
				end
			end,
			nil,
			nil
		)
		if todo == nil then return end
		for _, tCratedDecorData in pairs(tDecorCrateList) do
			table.insert(todo, {})
			todo[#todo].low = tCratedDecorData.tDecorItems[1].nDecorId
			todo[#todo].high = tCratedDecorData.tDecorItems[1].nDecorIdHi
		end
		Batcher:StartTimed(0.15)
	end
end

function KatiaBuilderToolkit:RevertSky()
	-- Set sky to something invalid
	HousingLib.GetResidence():ModifyResidenceDecor(nil,nil,nil,nil,1,nil,nil)
	self:FloatText("Original sky will be restored on next log-in")
end


-----------------------------------------------------
-- KatiaBuilderToolkitForm Functions
-----------------------------------------------------

function KatiaBuilderToolkit:OnKatiaBuilderMenu()
	local realmSet = self.donates[GameLib.GetRealmName()]
	if realmSet ~= nil then
		local player = GameLib.GetPlayerUnit()
		if player ~= nil and realmSet[player:GetFaction()] ~= nil then
			self.wndMenu:SetAnchorOffsets(-10, 5, 140, 315)
		end
	end
	if self.wndMenu:IsShown() then
		self.wndMenu:Close() -- hide the menu
	else
		self.wndMenu:Invoke() -- show the menu (in the main window)
	end
end

function KatiaBuilderToolkit:OnKatiaBuilderFind()
	DecorFinder:Open()
	self.wndMenu:Close() -- hide the menu
end

function KatiaBuilderToolkit:OnKatiaBuilderFindPlot()
	PlotFinder:Open()
	self.wndMenu:Close() -- hide the menu
end

function KatiaBuilderToolkit:OnKatiaBuilderCleaner()
	self.wndCleaner:Invoke()
	self.wndMenu:Close() -- hide the menu
end

function KatiaBuilderToolkit:OnKatiaBuilderInteractables()
	self.wndInteract:Invoke()
	self:RefreshTree()
	self.wndMenu:Close() -- hide the menu
end

function KatiaBuilderToolkit:OnKatiaBuilderRP()
	self.wndRP:Invoke()
	self.wndMenu:Close() -- hide the menu
	self:RefreshRP()
	if self.bReporter == nil then
		self.wndRPAsk:Invoke()
	end
end

function KatiaBuilderToolkit:OnCancel()
	self.wndMain:Close() -- hide the window
end

function KatiaBuilderToolkit:OnCancelShop()
	self.wndShop:Close() -- hide the window
end

function KatiaBuilderToolkit:OnCancelCleaner()
	self.wndCleaner:Close() -- hide the window
end

function KatiaBuilderToolkit:OnCancelInteractables()
	self.wndInteract:Close() -- hide the window
end

function KatiaBuilderToolkit:OnCancelRP()
	self.wndRP:Close() -- hide the window
end

function KatiaBuilderToolkit:OnCancelOptions()
	self.wndOptions:Close() -- hide the window
end

function KatiaBuilderToolkit:OnSlotDown()
	Increment(self.wndMain, "Slot", -1)
end

function KatiaBuilderToolkit:OnSlotUp()
	Increment(self.wndMain, "Slot", 1)
end

function KatiaBuilderToolkit:OnFromDown()
	Increment(self.wndMain, "From", -1)
end

function KatiaBuilderToolkit:OnFromUp()
	Increment(self.wndMain, "From", 1)
end

function KatiaBuilderToolkit:OnToDown()
	Increment(self.wndMain, "To", -1)
end

function KatiaBuilderToolkit:OnToUp()
	Increment(self.wndMain, "To", 1)
end

function KatiaBuilderToolkit:OnCopy()
	local slot = tonumber(self.wndMain:FindChild("Slot"):GetText())
	self:Copy(slot)
end

function KatiaBuilderToolkit:OnPaste()
	local slot = tonumber(self.wndMain:FindChild("Slot"):GetText())
	self:Paste(slot)
end

function KatiaBuilderToolkit:OnClone(wndHandler, wndControl, eMouseButton)
	local slot = tonumber(self.wndMain:FindChild("Slot"):GetText())
	local newDec = self:Clone(slot)
	self.bSelectNew = true
	Utils:Place()
end

function KatiaBuilderToolkit:SelectParent()
	local selDecor = HousingLib.GetResidence():GetSelectedDecor()
	if selDecor == nil then
		self:FloatText("No decor selected")
		return
	end
	local parDecor = selDecor:GetParent()
	if parDecor ~= nil then
		parDecor:Select()
	end
	DecorEditor:Refresh()
end

function KatiaBuilderToolkit:OnPlace()
	Utils:Place()
end

function KatiaBuilderToolkit:OnCrate()
	if Apollo.IsShiftKeyDown() then
		Utils:CrateLinkedSet()
	else
		Utils:Crate()
	end
end

function KatiaBuilderToolkit:OnShopPageUp( wndHandler, wndControl, eMouseButton )
	Increment(self.wndShop, "Page", 1)
	local top = #self.shopresults
	if top == nil then
		self.wndShop:FindChild("Page"):SetText("1")
	else
		local perpage = tonumber(self.wndShop:FindChild("MaxResults"):GetText())
		top = math.floor((top + perpage - 1) / perpage)
		if top == 0 then top = 1 end
		if tonumber(self.wndShop:FindChild("Page"):GetText()) > top then self.wndShop:FindChild("Page"):SetText(tostring(top)) end
	end
	self:ShowShopResults()
end

function KatiaBuilderToolkit:OnShopPageDown( wndHandler, wndControl, eMouseButton )
	Increment(self.wndShop, "Page", -1)
	if tonumber(self.wndShop:FindChild("Page"):GetText()) < 1 then self.wndShop:FindChild("Page"):SetText("1") end
	self:ShowShopResults()
end

function KatiaBuilderToolkit:ApplyOptions()
	if self.options.bTranBGMain then
		self.wndMain:SetBGOpacity(0)
	else
		self.wndMain:SetBGOpacity(1)
	end
	if self.options.bTranBGSet then
		SetManager:SetBGOpacity(0)
	else
		SetManager:SetBGOpacity(1)
	end
	if self.options.bTranBGDecor then
		DecorEditor:SetBGOpacity(0)
	else
		DecorEditor:SetBGOpacity(1)
	end
	if self.options.bTranBGDecorFinder then
		DecorFinder:SetBGOpacity(0)
	else
		DecorFinder:SetBGOpacity(1)
	end
	if self.options.bTranBGPlotFinder then
		PlotFinder:SetBGOpacity(0)
	else
		PlotFinder:SetBGOpacity(1)
	end
	for key, val in pairs(self.options) do
		local box = self.wndOptions:FindChild(string.sub(key,6))
		if box ~= nil then
			box:SetCheck(val)
		end
	end
end

function KatiaBuilderToolkit:OnOptionChange(wndHandler, wndControl)
	local strOption = "bTran" .. wndHandler:GetName()
	self.options[strOption] = wndHandler:IsChecked()
	self:ApplyOptions()
end


-----------------------------------------------------
-- KatiaBuilderToolkit Persistence
-----------------------------------------------------

function KatiaBuilderToolkit:OnSave(eLevel)
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Character then
		local tSave = {}
		tSave.slots = self.slots
		tSave.savedSnapshot = self.savedSnapshot
		return tSave
	elseif eLevel == GameLib.CodeEnumAddonSaveLevel.Realm then
		local tSave = {}
		tSave.setdirectory = SetManager.setdirectory
		tSave.catalog = self.catalog
		tSave.highestKnownDecorID = self.highestKnownDecorID
		tSave.options = self.options
		tSave.checklist = self.checklist
		tSave.acknowledged = self.acknowledged
		tSave.rpplots = self.rpplots
		for k,_ in pairs(tSave.rpplots) do
			tSave.rpplots[k].population = nil
			tSave.rpplots[k].updated = nil
		end
		tSave.bReporter = self.bReporter
		return tSave
	end
end

function KatiaBuilderToolkit:OnRestore(eLevel, tData)
	if tData == nil then return end
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Character then
		if tData.sets ~= nil then
			local folder = "import - " .. GameLib.GetPlayerCharacterName()
			if self.setdirectory[folder] == nil then self.setdirectory[folder] = {} end
			for i, set in pairs(tData.sets) do
				if tData.setnames ~= nil and tData.setnames[i] ~= nil and tData.setnames[i] ~= "" and
					self.setdirectory[folder][tData.setnames[i]] == nil then
					self.setdirectory[folder][tData.setnames[i]] = set
				elseif self.setdirectory[folder][i] == nil then
					self.setdirectory[folder][i] = set
				else
					table.insert(self.setdirectory[folder], set)
				end
			end
		end
		self.slots = tData.slots
		self.savedSnapshot = tData.savedSnapshot
		if self.catalog == nil then
			self.catalog = tData.catalog
		end
		if tData.options ~= nil and self.options == nil then
			self.options = tData.options
		end
	elseif eLevel == GameLib.CodeEnumAddonSaveLevel.Realm then
		self.checklist = tData.checklist
		if tData.acknowledged ~= nil then
			self.acknowledged = tData.acknowledged
		end
		if tData.setdirectory == nil then
			SetManager.setdirectory = {}
		else
			SetManager.setdirectory = tData.setdirectory
		end
		if tData.rpplots == nil then
			self.rpplots = {}
		else
			self.rpplots = tData.rpplots
			for k,_ in pairs(self.rpplots) do
				self.rpplots[k].population = 0
				self.rpplots[k].updated = nil
			end
		end
		self.bReporter = tData.bReporter
		self.catalog = tData.catalog
		if self.highestKnownDecorID == nil or tData.highestKnownDecorID < self.highestKnownDecorID then
			self.highestKnownDecorID = tData.highestKnownDecorID
		end
		if tData.options ~= nil then
			self.options = tData.options
		end
	end
end


-----------------------------------------------------
-- KatiaBuilderToolkit Interactables
-----------------------------------------------------

function KatiaBuilderToolkit:Distance(posA, posB)
	return math.sqrt((posB.x - posA.x)^2 + (posB.y - posA.y)^2 + (posB.z - posA.z)^2)
end

function KatiaBuilderToolkit:AngularDifference(angA, angB)
	return math.abs(((angA - angB + 180) % 360) - 180)
end

function KatiaBuilderToolkit:OnInteractTick()
	local residence = HousingLib.GetResidence()
	if residence == nil then return end
	local plotname = residence:GetPropertyOwnerName()
	if self.checklist[plotname] == nil then return end
	if not self.wndInteract:FindChild("Active"):IsChecked() then return end
	if HousingLib.IsInEditMode() then return end

	for i, trigger in ipairs(self.checklist[plotname]) do
		if trigger.low ~= nil and trigger.high ~= nil then
			local dec = HousingLib.GetResidence():GetDecorById(trigger.low, trigger.high)
			if dec ~= nil then
				local unit = dec:GetAttachedUnit()
				if unit ~= nil then
					local state = unit:GetStandState()
					if trigger.states[state] ~= nil then
						for j, move in ipairs(trigger.states[state]) do
							local dec = HousingLib.GetResidence():GetDecorById(
								move.low, move.high)
							if dec ~= nil and dec:GetName() ~= "" then
								local info = dec:GetDecorIconInfo()
								local decpos = {
									x = info.fWorldPosX,
									y = info.fWorldPosY,
									z = info.fWorldPosZ
								}
								if self:Distance(decpos, move.pos) > 0.05 or
									math.abs(info.fScaleCurrent - move.pos.s) > .03 or
									self:AngularDifference(info.fPitch, move.pos.p) > 1 or
									self:AngularDifference(info.fRoll, move.pos.r) > 1 or
									self:AngularDifference(info.fYaw, move.pos.yaw) > 1 then
									dec:Select()
									dec:SetPosition(move.pos.x,
										move.pos.y,
										move.pos.z)
									dec:SetRotation(move.pos.p,
										move.pos.r,
										move.pos.yaw)
									dec:SetScale(move.pos.s)
									dec:Place()
									return
								end
							end
						end
					end
				end
			end
		end
	end
end

function KatiaBuilderToolkit:OnAddInteractables()
	local residence = HousingLib.GetResidence()
	if residence == nil then return end
	local selected = residence:GetSelectedDecor()
	if selected == nil then
		self:FloatText("Select the decor you want to move")
		return
	end
	local selectedlow, selectedhigh = selected:GetId()
	local selectedname = selected:GetName()
	local plotname = residence:GetPropertyOwnerName()

	local tree = self.wndInteract:FindChild("Checklist")
	local node = tree:GetSelectedNode()
	if node == nil then
		self:FloatText("Select the trigger state you want to add a movement to")
		return
	end
	local data = tree:GetNodeData(node)
	if data == nil or data.add == nil then
		self:FloatText("Select the trigger state you want to add a movement to")
		return
	end
	if data.add.i_plot ~= plotname then
		self:FloatText("Do this on the appropriate plot")
		return
	end
	
	local statenode = self.checklist[plotname][data.add.i_trigger].states[data.add.i_state]
	local decorinfo = selected:GetDecorIconInfo()
	local move = {
		low = selectedlow,
		high = selectedhigh,
		name = selectedname,
		pos = {
			x = decorinfo.fWorldPosX,
			y = decorinfo.fWorldPosY,
			z = decorinfo.fWorldPosZ,
			p = decorinfo.fPitch,
			r = decorinfo.fRoll,
			yaw = decorinfo.fYaw,
			s = decorinfo.fScaleCurrent
		},
	}
	table.insert(statenode, move)
	local movestring = string.format("%s, x=%.2f, y=%.2f, z=%.2f, pitch=%.2f, roll=%.2f, yaw=%.2f, size=%.2f", move.name, move.pos.x, move.pos.y, move.pos.z, move.pos.p, move.pos.r, move.pos.yaw, move.pos.s)
	local movenode = tree:AddNode(node, movestring, "", { parent=statenode, label=#statenode,
		guide={x=move.pos.z+1472, y=move.pos.y-715, z=1440-move.pos.x} })
	tree:ExpandNode(node)
end

function KatiaBuilderToolkit:OnRemoveInteractables()
	local tree = self.wndInteract:FindChild("Checklist")
	local node = tree:GetSelectedNode()
	if node == nil then return end
	local data = tree:GetNodeData(node)
	if type(data.label) == "number" then
		table.remove(data.parent, data.label)
	else
		data.parent[data.label] = nil
	end
	self:RefreshTree()
end

function KatiaBuilderToolkit:OnSelectInteractables()
	local tree = self.wndInteract:FindChild("Checklist")
	local node = tree:GetSelectedNode()
	if node == nil then return end
	local data = tree:GetNodeData(node)
	if data == nil or data.guide == nil then return end
	if type(data.guide) == "string" then
		if HousingLib.GetResidence():GetPropertyOwnerName() == data.guide then
			for _, dec in pairs(HousingLib.GetResidence():GetPlacedDecorList()) do
				local unit = dec:GetAttachedUnit()
				if unit ~= nil then
					for i, trigger in pairs(self.checklist[data.guide]) do
						if (trigger.low == nil or trigger.high == nil) and
							self:Distance(unit:GetPosition(), trigger.pos) < .05 then
							self.checklist[data.guide][i].low, self.checklist[data.guide][i].high = dec:GetId()
						end
					end
				end
			end
		else
			self:FloatText("Do this on the plot where the trigger is")
		end
		self:RefreshTree()
	else
		self.guide = data.guide
		self.guideCount = 100
		self.guideTimer = ApolloTimer.Create(0.03, true, "OnGuideTick", self)
		self.guideTimer:Start()
	end
end

function KatiaBuilderToolkit:OnGuideTick()
	self.wndBack:DestroyAllPixies()
	if self.guide == nil or self.guideCount <= 0 then
		self.guideTimer:Stop()
		return
	end
	local player = GameLib.GetPlayerUnit()
	if player == nil then
		return
	end
	local pPos = player:GetPosition()
	local pScreen = GameLib.WorldLocToScreenPoint(Vector3.New(pPos.x, pPos.y, pPos.z))
	
	local dScreen = GameLib.WorldLocToScreenPoint(Vector3.New(self.guide.x, self.guide.y, self.guide.z))
	self.wndBack:AddPixie( {
		bLine = true, fWidth = 2, cr = {a=1,r=1,g=0,b=0},
		loc = { fPoints = { 0, 0, 0, 0 }, nOffsets = { dScreen.x, dScreen.y, pScreen.x, pScreen.y } }
	} )
	
	self.guideCount = self.guideCount - 1
end

function KatiaBuilderToolkit:RefreshTree(triggerindex)
	local tree = self.wndInteract:FindChild("Checklist")
	tree:DeleteAll()
	local owner = HousingLib.GetResidence():GetPropertyOwnerName()
	
	for name, triggers in pairs(self.checklist) do
		local namenode = tree:AddNode(0, name, "", { parent=self.checklist, label=name })
		if name ~= owner then
			tree:CollapseNode(namenode)
		end
		for i, trigger in ipairs(triggers) do
			local triggernode
			if trigger.low == nil or trigger.high == nil then
				local triggerstring = string.format("%s <click to synchronize>", trigger.n)
				triggernode = tree:AddNode(namenode, triggerstring, "", { parent=triggers, label=i, guide=name })
			else
				local dec = HousingLib.GetResidence():GetDecorById(trigger.low, trigger.high)
				if dec == nil or dec:GetAttachedUnit() == nil then
					local triggerstring = string.format("%s <defunct>", trigger.n)
					triggernode = tree:AddNode(namenode, triggerstring, "", { parent=triggers, label=i })
				else
					trigger.pos = dec:GetAttachedUnit():GetPosition()
					local triggerstring = string.format("%s, x=%.2f, y=%.2f, z=%.2f", trigger.n, trigger.pos.x, trigger.pos.y, trigger.pos.z)
					triggernode = tree:AddNode(namenode, triggerstring, "", { parent=triggers, label=i, guide=trigger.pos })
				end
			end
			if i ~= triggerindex then
				tree:CollapseNode(triggernode)
			end
			for state, moves in pairs(trigger.states) do
				local statenode = tree:AddNode(triggernode, state, "", { parent=trigger.states, label=state, add = { i_plot=name, i_trigger=i, i_state=state} })
				tree:CollapseNode(statenode)
				for j, move in ipairs(moves) do
					local movestring = string.format("%s, x=%.2f, y=%.2f, z=%.2f, pitch=%.2f, roll=%.2f, yaw=%.2f, size=%.2f", move.name, move.pos.x, move.pos.y, move.pos.z, move.pos.p, move.pos.r, move.pos.yaw, move.pos.s)
					local movenode = tree:AddNode(statenode, movestring, "", { parent=moves, label=j,
						guide={x=move.pos.z+1472, y=move.pos.y-715, z=1440-move.pos.x} })
				end
			end
		end
	end
end

function KatiaBuilderToolkit:OnTargetInteractables()
	local residence = HousingLib.GetResidence()
	if residence == nil then return end
	local plotname = residence:GetPropertyOwnerName()
	local target = GameLib.GetTargetUnit()
	if target == nil then
		self:FloatText("Select the trigger unit and state you want to add")
		return
	end
	local targetname = target:GetName()
	local targetpos = target:GetPosition()
	local targetid = target:GetId()
	local targetstate = target:GetStandState()
	if targetpos == nil or targetname == nil or targetstate == nil or targetid == nil or
		plotname == "" then
		return
	end
	if self.checklist[plotname] == nil then self.checklist[plotname] = {} end
	local plotnode = self.checklist[plotname]
	local triggernode = nil
	local triggerindex = nil
	for i, node in pairs(plotnode) do
		if node.low ~= nil and node.high ~= nil then
			local dec = HousingLib.GetResidence():GetDecorById(node.low, node.high)
			if dec ~= nil then
				local unit = dec:GetAttachedUnit()
				if unit ~= nil and unit:GetId() == targetid then
					triggernode = node
					triggerindex = i
				end
			end
		else
			if self:Distance(targetpos, node.pos) < .05 then triggernode = node end
		end
	end
	if triggernode == nil then
		local found_low, found_high
		for _, dec in pairs(HousingLib.GetResidence():GetPlacedDecorList()) do
			local unit = dec:GetAttachedUnit()
			if unit ~= nil then
				if self:Distance(unit:GetPosition(), targetpos) < .05 then
					found_low, found_high = dec:GetId()
				end
			end
		end
		table.insert(plotnode, { n=targetname, pos=targetpos, states={}, low = found_low, high = found_high })
		triggernode = plotnode[#plotnode]
		triggerindex = #plotnode
	end
	if triggernode.states[targetstate] == nil then
		triggernode.states[targetstate] = {}
	end
	self:RefreshTree(triggerindex)
end

function KatiaBuilderToolkit:OnCleanCrate()
	local cash = self.wndCleaner:FindChild("Cash"):GetAmount():GetAmount()
	if cash == nil then
		self:FloatText("Bad cash amount")
		return
	end
	local renown = tonumber(self.wndCleaner:FindChild("Renown"):GetText())
	if renown == nil then
		self:FloatText("Bad renown amount")
		return
	end
	self:CleanCrate(cash, renown, false)
end

function KatiaBuilderToolkit:OnCrateNuke( wndHandler, wndControl, eMouseButton )
	self:CleanCrate(0, 0, true)
end

function KatiaBuilderToolkit:CleanCrate(cashlimit, renownlimit, all)
	if not HousingLib.IsOnMyResidence() then
		self:FloatText("You can only do this on your plot!")
		return
	end

	local todo = Batcher:Prepare(
		function (_, decdata)
			HousingLib.GetResidence():DestroyDecorFromCrate(decdata.nDecorId, decdata.nDecorIdHi)
		end,
		nil,
		nil
	)
	if todo == nil then return end

	local vendorlist = HousingLib.GetDecorCatalogList()
	local cleanlist = {}
	for i, decinfo in pairs(vendorlist) do
		if (decinfo.eCurrencyType == 1 and decinfo.nCost <= cashlimit) or (decinfo.eCurrencyType ~= 1 and decinfo.nCost <= renownlimit) then
			cleanlist[decinfo.strName] = true
		end
	end
	
	for _, data in pairs(HousingLib.GetResidence():GetDecorCrateList()) do
		if cleanlist[data.strName] or (all == true) then
			for _, decdata in pairs(data.tDecorItems) do
				table.insert(todo, decdata)
			end
		end
	end

	Batcher:StartDecorDriven()
end

-----------------------------------------------------
-- KatiaBuilderToolkit RP Finder
-----------------------------------------------------

function KatiaBuilderToolkit:OnRPMonReceived(iccomm, strMessage, strSender)
--	Print(strSender .. " sent " .. strMessage)
	local index = string.find(strMessage, " [^ ]*$")
	local pop = tonumber(string.sub(strMessage, index+1))
	local owner = string.sub(strMessage, 1, index-1)
	if pop == nil or owner == nil then return end
	if self.rpplots[owner] == nil then
		self.wndRP:FindChild("Title"):SetText("Catalog needs to be updated from https://goo.gl/Q2DvjD")
		self.wndRP:FindChild("Title"):SetTextColor({r=1,b=0,g=0,a=1})
	else
		self.rpplots[owner].population = pop
		self.rpplots[owner].updated = 1
		self:RefreshRP()

		local res = HousingLib.GetResidence()
		if res ~= nil and owner == res:GetPropertyOwnerName() and self.playersSeen <= pop and self.rpReportTimer ~= nil then
			self.rpReportTimer:Stop()
			self.rpReportTimer = ApolloTimer.Create(30 + math.random(120), false, "RPReport", self)
		end
	end
end

function KatiaBuilderToolkit:RPDecay()
	for owner, plot in pairs(self.rpplots) do
		if self.rpplots[owner].updated == nil or self.rpplots[owner].updated <= 0 then
			self.rpplots[owner].updated = 0
			self.rpplots[owner].population = 0
		else
			self.rpplots[owner].updated = self.rpplots[owner].updated - 1
		end
	end
	self.playersSeen = 0
	for _,_ in pairs(self.players) do
		self.playersSeen = self.playersSeen + 1
	end
	self:RefreshRP()
end

function KatiaBuilderToolkit:RPReport()
	local res = HousingLib.GetResidence()
	if res ~= nil and self.bReporter then
		local owner = res:GetPropertyOwnerName()
		if self.rpplots[owner] ~= nil then
			self.rpmonComm:SendMessage(owner .. " " .. self.playersSeen)
			self:OnRPMonReceived("", owner .. " " .. self.playersSeen, "")
		end
	end
	self.rpReportTimer = ApolloTimer.Create(30 + math.random(120), false, "RPReport", self)
end

function KatiaBuilderToolkit:RefreshRP()
	local owners = {}
	for owner, _ in pairs(self.rpplots) do table.insert(owners, owner) end
	table.sort(owners, function(a, b)
		if self.rpplots[a].population == nil then return false end
		if self.rpplots[b].population == nil then return true end
		return self.rpplots[a].population > self.rpplots[b].population
	end)

	local wndList = self.wndRP:FindChild("List")
	wndList:DestroyChildren()
	for _, owner in ipairs(owners) do
		if owner ~= nil and owner ~= "" then
			local wndListItem = Apollo.LoadForm(self.xmlDoc, "RPListItem", wndList, self)
			local blockText = ""
			if self.rpplots[owner][4] == "closed" and ((self.rpplots[owner][1] == "Dominion" and GameLib.GetPlayerBaseFaction() == 167) or (self.rpplots[owner][1] == "Exile" and GameLib.GetPlayerBaseFaction() == 166)) then
				blockText = " (XFAC RP BLOCKED)"
			end
			wndListItem:SetText(self.rpplots[owner][2] .. "    (" .. owner .. ") - ".. self.rpplots[owner][1] .. blockText)
			wndListItem:SetData(owner)
			local pop = self.rpplots[owner].population
			if pop ~= nil and pop > 2 then
				pop = math.min(15, pop)
				wndListItem:SetTextColor({a=1, r=1, g=1 - (pop/15), b=0.25})
			end
		end
	end
	wndList:ArrangeChildrenVert()
	
	self.wndRP:FindChild("Report"):SetCheck(self.bReporter)
end

function KatiaBuilderToolkit:OnReportChange()
	self.bReporter = self.wndRP:FindChild("Report"):IsChecked()
end

function KatiaBuilderToolkit:OnReportYes()
	self.bReporter = true
    self.wndRPAsk:Show(false, true)
	self:RefreshRP()
end

function KatiaBuilderToolkit:OnReportNo()
	self.bReporter = false
    self.wndRPAsk:Show(false, true)
	self:RefreshRP()
end

function KatiaBuilderToolkit:OnUpdateRP()
	local code = self.wndRP:FindChild("Code"):GetText()
	if code == "Copy the code from https://goo.gl/Q2DvjD" then
		self:FloatText("Copy the code from https://goo.gl/Q2DvjD")
		return
	end
	self.rpplots = self:LoadTable(code)
	self:RefreshRP()
	self.wndRP:FindChild("Title"):SetText("The Katia RP Finder")
	self.wndRP:FindChild("Title"):SetTextColor({r=1,b=1,g=1,a=1})
end

function KatiaBuilderToolkit:OnRPSelect(wndHandler, wndControl, eMouseButton)
	local owner = wndHandler:GetData()
	if eMouseButton == GameLib.CodeEnumInputMouse.Left then
		local plot = self.rpplots[owner]
		self.wndRP:FindChild("PlotName"):SetText("Plot name:     " .. plot[2] .. " (" .. owner .. ")")
		self.wndRP:FindChild("Venue"):SetText("Venue:     " .. plot[3])
		self.wndRP:FindChild("Faction"):SetText("Faction:     " .. plot[1])
		self.wndRP:FindChild("18+"):SetText("18+:     " .. plot[6])
		self.wndRP:FindChild("XFac"):SetText("XFac:     " .. plot[4])
		self.wndRP:FindChild("Open"):SetText("Open:     " .. plot[5])
		self.wndRP:FindChild("Visit"):SetData(owner)
	elseif eMouseButton == GameLib.CodeEnumInputMouse.Right then
		self:Visit(owner)
	end
end

function KatiaBuilderToolkit:OnVisitRP(wndHandler, wndControl, eMouseButton)
	local owner = wndHandler:GetData()
	if owner ~= nil then
		self:Visit(owner)
	end
end

function KatiaBuilderToolkit:OnDiff()
	local fromslot = tonumber(self.wndMain:FindChild("From"):GetText())
	local toslot = tonumber(self.wndMain:FindChild("To"):GetText())
	self:Diff(fromslot, toslot)
end

function KatiaBuilderToolkit:OnAverage()
	local fromslot = tonumber(self.wndMain:FindChild("From"):GetText())
	local toslot = tonumber(self.wndMain:FindChild("To"):GetText())
	self:Average(fromslot, toslot)
end

function KatiaBuilderToolkit:LoadTable(Input)
   return assert(loadstring('return '.. Input ))()
end


-----------------------------------------------------
-- KatiaBuilderToolkit Instance
-----------------------------------------------------

local KatiaBuilderToolkitInst = KatiaBuilderToolkit:new()
KatiaBuilderToolkitInst:Init()
