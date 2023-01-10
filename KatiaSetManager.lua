require "ICComm"
local MAJOR, MINOR = "Module:KatiaSetManager-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local KatiaSetManager = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
KatiaSetManager.null = setmetatable ({}, {
  __toinn = function () return "null" end
})
local Utils = Apollo.GetPackage("Module:KatiaBuildUtils-1.0").tPackage
local Batcher = Apollo.GetPackage("Module:KatiaBatcher-1.0").tPackage

-- Display screen message to user
local function FloatText(strMessage)
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

function KatiaSetManager:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("KatiaSetManager.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)

	self.setdirectory = {}
	self.connectTimer = APolloTimer.Create(1, true, "ConnectXfer", self)
	self.connectTimer:Start()
end

function KatiaSetManager:ConnectXfer()
	if not self.xferComm then
		self.xferComm = ICCommLib.JoinChannel("KBTXFer", ICCommLib.CodeEnumICCommChannelType.Global);
		if self.xferComm then
			self.xferComm:SetReceivedMessageFunction("OnXFerReceived", self)
		end
	else
		self.connectTimer:Stop()
	end
end

function KatiaSetManager:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndSet = Apollo.LoadForm(self.xmlDoc, "SetForm", nil, self)
		if self.wndSet == nil then
			Apollo.AddAddonErrorText(self, "Could not load the set window for some reason.")
			return
		end
		
	    self.wndShare = Apollo.LoadForm(self.xmlDoc, "ShareForm", nil, self)
		if self.wndShare == nil then
			Apollo.AddAddonErrorText(self, "Could not load the sharing window for some reason.")
			return
		end

	    self.wndSet:Show(false, true)
	    self.wndShare:Show(false, true)
		if self.bgOpacity ~= nil then
			self.wndSet:SetBGOpacity(self.bgOpacity)
		end
	end
end

function KatiaSetManager:Open()
	self.wndSet:Invoke() -- show the window
	self:Refresh()
	self:RefreshDirectory()
	self:Refresh()
end

function KatiaSetManager:Close()
	self.wndSet:Close() -- hide the window
end

function KatiaSetManager:SetBGOpacity(value)
	self.bgOpacity = value
	if self.wndSet ~= nil then
		self.wndSet:SetBGOpacity(value)
	end
end

function KatiaSetManager:RefreshDirectory(currentfolder, currentset)
	local tree = self.wndSet:FindChild("Directory")
	tree:DeleteAll()
	
	local foldernames = {}
	for n in pairs(self.setdirectory) do table.insert(foldernames, n) end
	table.sort(foldernames)
	
	for _, foldername in pairs(foldernames) do
		local dirnode = tree:AddNode(0, foldername, "", { folder = foldername })
		if foldername ~= currentfolder then
			tree:CollapseNode(dirnode)
		end
		local setnames = {}
		for n in pairs(self.setdirectory[foldername]) do table.insert(setnames, n) end
		table.sort(setnames, intnumcomparator)
		for _, n in pairs(setnames) do
			local setnode = tree:AddNode(dirnode, n, "", { folder = foldername, set = n })
			if n == currentset then
				tree:SelectNode(setnode)
				self.selectedset = { folder = currentfolder, set = currentset}
			end
		end
	end
	self:Refresh()
end

function KatiaSetManager:Refresh()
	local wndList = self.wndSet:FindChild("List")
	wndList:DestroyChildren()
	if self.selectedset == nil or self.selectedset.set == nil then
		return
	end
	if self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		self.setdirectory[self.selectedset.folder][self.selectedset.set] = {}
	end
	for i, d in pairs(self.setdirectory[self.selectedset.folder][self.selectedset.set]) do
		local wndListItem = Apollo.LoadForm(self.xmlDoc, "ListItem", wndList, self)
		local data = {}
		data.index = i
		wndListItem:SetText(i .. " - " .. d.N)
		wndListItem:SetData(data)
		if i == self.selected then
			wndListItem:SetTextColor({a=1, r=0, g=0.5, b=1})
		end
	end
	wndList:ArrangeChildrenVert()
	if self.selected ~= nil then
		wndList:SetVScrollPos((self.selected - 1) * 15)
	end
end

-- Compact decor serialization (used for xfer)
local kCharNum = { ["a"]=0, ["b"]=1, ["c"]=2, ["d"]=3, ["e"]=4, ["f"]=5, ["g"]=6, ["h"]=7, ["i"]=8, ["j"]=9, ["k"]=10, ["l"]=11, ["m"]=12, ["n"]=13, ["o"]=14, ["p"]=15, ["q"]=16, ["r"]=17, ["s"]=18, ["t"]=19, ["u"]=20, ["v"]=21, ["w"]=22, ["x"]=23, ["y"]=24, ["z"]=25, ["A"]=26, ["B"]=27, ["C"]=28, ["D"]=29, ["E"]=30, ["F"]=31, ["G"]=32, ["H"]=33, ["I"]=34, ["J"]=35, ["K"]=36, ["L"]=37, ["M"]=38, ["N"]=39, ["O"]=40, ["P"]=41, ["Q"]=42, ["R"]=43, ["S"]=44, ["T"]=45, ["U"]=46, ["V"]=47, ["W"]=48, ["X"]=49, ["Y"]=50, ["Z"]=51, ["1"]=52, ["2"]=53, ["3"]=54, ["4"]=55, ["5"]=56, ["6"]=57, ["7"]=58, ["8"]=59, ["9"]=60, ["0"]=61, ["!"]=62, ["@"]=63, ["#"]=64, ["$"]=65, ["%"]=66, ["^"]=67, ["&"]=68, ["*"]=69, ["("]=70, [")"]=71, ["`"]=72, ["-"]=73, ["="]=74, ["["]=75, ["]"]=76, ["\\"]=77, [";"]=78, ["'"]=79, [","]=80, ["."]=81, ["/"]=82, ["~"]=83, ["_"]=84, ["+"]=85, ["{"]=86, ["}"]=87, ["|"]=88, [":"]=89, ["\""]=90, ["<"]=91, [">"]=92, ["?"]=93
}

local kNumChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()`-=[]\\;',./~_+{}|:\"<>?"

local function SerializeDigit(d)
	return string.sub(kNumChars, d+1, d+1)
end

local function SerializeId(id)
	return SerializeDigit(id / 93) .. SerializeDigit(id % 93)
end

local function DeserializeId(id)
	return kCharNum[string.sub(id, 1, 1)] * 93 + kCharNum[string.sub(id, 2, 2)]
end

local function SerializeValue(val)
	local adjustedVal = math.floor(val * 1000 + 30000000)
	return SerializeDigit(adjustedVal / (93 * 93 * 93)) ..
			SerializeDigit((adjustedVal / (93 * 93)) % 93) ..
			SerializeDigit((adjustedVal / 93) % 93) ..
			SerializeDigit(adjustedVal % 93)
end

local function DeserializeValue(val)
	local adjustedVal = kCharNum[string.sub(val, 1, 1)] * 93 * 93 * 93 +
						kCharNum[string.sub(val, 2, 2)] * 93 * 93 +
						kCharNum[string.sub(val, 3, 3)] * 93 +
						kCharNum[string.sub(val, 4, 4)]
	return (adjustedVal - 30000000) / 1000
end

function KatiaSetManager:OnXFerReceived(iccomm, strMessage, strSender)
	if not self.receiving or self.selectedset == nil or self.selectedset.set == nil then
		return
	end
	if strMessage == "done" then
		self.receiving = false
		self.wndSet:FindChild("Recv"):SetOpacity(1)
		return
	end
	local numDec = string.len(strMessage) / 30
	for i=1,numDec do
		local newDec = {}
		local id = DeserializeId(string.sub(strMessage,(i-1)*30+1,(i-1)*30+2))
		newDec.I = id
		newDec.N = DecorIdToName(id)
		newDec.X = DeserializeValue(string.sub(strMessage, (i-1)*30+3, (i-1)*30+6))
		newDec.Y = DeserializeValue(string.sub(strMessage, (i-1)*30+7, (i-1)*30+10))
		newDec.Z = DeserializeValue(string.sub(strMessage, (i-1)*30+11, (i-1)*30+14))
		newDec.P = DeserializeValue(string.sub(strMessage, (i-1)*30+15, (i-1)*30+18))
		newDec.R = DeserializeValue(string.sub(strMessage, (i-1)*30+19, (i-1)*30+22))
		newDec.Yaw = DeserializeValue(string.sub(strMessage, (i-1)*30+23, (i-1)*30+26))
		newDec.S = DeserializeValue(string.sub(strMessage, (i-1)*30+27, (i-1)*30+30))
		table.insert(self.setdirectory[self.selectedset.folder][self.selectedset.set], newDec)
	end
	self:Refresh()
end

function KatiaSetManager:OnRecv()
	if self.receiving then
		self.receiving = false
		self.wndSet:FindChild("Recv"):SetOpacity(1)
	else
		self.receiving = true
		self.wndSet:FindChild("Recv"):SetOpacity(0.5)
		FloatText("Now receiving, the button will pop up when set xfer is complete")
	end
end

function KatiaSetManager:OnXFer()
	local target = GameLib.GetPlayerUnit():GetTarget()
	if target == nil or not target:IsACharacter() then
		FloatText("Target a player to receive your set")
		return
	end
	if self.selectedset == nil or self.selectedset.set == nil then
		FloatText("Select a set to transfer")
		return
	end
	local todo = Batcher:Prepare(
		function (_, tosend)
			self.xferComm:SendPrivateMessage(self.recipient, tosend)
		end,
		nil,
		function (_, tosend)
			FloatText("Transfer complete, but recipient may need time to receive all parts")
		end
	)
	if todo == nil then return end
	self.recipient = target:GetName()
	local xferstring = ""
	for _, pack in pairs(self.setdirectory[self.selectedset.folder][self.selectedset.set]) do
		xferstring = xferstring ..
			SerializeId(pack.I) ..
			SerializeValue(pack.X) ..
			SerializeValue(pack.Y) ..
			SerializeValue(pack.Z) ..
			SerializeValue(pack.P) ..
			SerializeValue(pack.R) ..
			SerializeValue(pack.Yaw) ..
			SerializeValue(pack.S)
		if string.len(xferstring) >= 90 then
			table.insert(todo, xferstring)
			xferstring = ""
		end
	end
	if xferstring ~= "" then
		table.insert(todo, xferstring)
	end
	table.insert(todo, "done")
	Batcher:StartTimed(2)
end

function KatiaSetManager:OnSelectSet()
	local tree = self.wndSet:FindChild("Directory")
	local node = tree:GetSelectedNode()
	if node == nil then return end
	local data = tree:GetNodeData(node)
	if data ~= nil then
		if self.moving == nil then
			self.selectedset = data
		elseif self.setdirectory[data.folder][self.moving.set] ~= nil then
			FloatText("Destination already has a set of that name!")
		else  -- directory movement
			self.setdirectory[data.folder][self.moving.set] = self.setdirectory[self.moving.folder][self.moving.set]
			self.setdirectory[self.moving.folder][self.moving.set] = nil
			self:RefreshDirectory(data.folder, self.moving.set)
			self.selectedset = { folder = data.folder, set = self.moving.set }
			self.moving = nil
			local button = self.wndSet:FindChild("MoveSet")
			button:SetText("Move")
			button:SetOpacity(1)
		end
	else
		self.selectedset = nil
	end
	self:Refresh()
end

function KatiaSetManager:OnNewDir()
	local name = self.wndSet:FindChild("Name"):GetText()
	if name == nil or name == "" then
		FloatText("Please specify a name.")
	elseif self.setdirectory[name] ~= nil then
		FloatText("Directory already exists!")
	else
		self.setdirectory[name] = {}
		self:RefreshDirectory()
	end
end

function KatiaSetManager:OnRenameDir()
	local name = self.wndSet:FindChild("Name"):GetText()
	if name == nil or name == "" then
		FloatText("Please specify a name.")
	elseif self.selectedset == nil then
		FloatText("No directory selected.")
	elseif self.setdirectory[name] ~= nil then
		FloatText("Directory already exists!")
	else
		self.setdirectory[name] = self.setdirectory[self.selectedset.folder]
		self.setdirectory[self.selectedset.folder] = nil
		self.selectedset = nil
		self:RefreshDirectory(name)
	end
end

function KatiaSetManager:OnRemoveDir()
	if self.selectedset == nil then
		FloatText("No directory selected.")
	elseif next(self.setdirectory[self.selectedset.folder]) ~= nil then
		FloatText("Directory is not empty!")
	else
		self.setdirectory[self.selectedset.folder] = nil
		self.selectedset = nil
		self:RefreshDirectory()
	end
end

function KatiaSetManager:OnNewSet()
	local name = self.wndSet:FindChild("Name"):GetText()
	if name == nil or name == "" then
		FloatText("Please specify a name.")
	elseif self.selectedset == nil then
		FloatText("Please select a directory.")
	elseif self.setdirectory[self.selectedset.folder][name] ~= nil then
		FloatText("Set already exists!")
	else
		self.setdirectory[self.selectedset.folder][name] = {}
		self.selectedset.set = name
		self:RefreshDirectory(self.selectedset.folder, name)
	end
end

function KatiaSetManager:OnRenameSet()
	local name = self.wndSet:FindChild("Name"):GetText()
	if name == nil or name == "" then
		FloatText("Please specify a name.")
	elseif self.selectedset == nil or self.selectedset.set == nil then
		FloatText("Please select a set.")
	elseif self.setdirectory[self.selectedset.folder][name] ~= nil then
		FloatText("Set already exists!")
	else
		self.setdirectory[self.selectedset.folder][name] = self.setdirectory[self.selectedset.folder][self.selectedset.set]
		self.setdirectory[self.selectedset.folder][self.selectedset.set] = nil
		self.selectedset.set = name
		self:RefreshDirectory(self.selectedset.folder, name)
	end
end

function KatiaSetManager:OnRemoveSet()
	if self.selectedset == nil or self.selectedset.set == nil then
		FloatText("Please select a set.")
	else
		self.setdirectory[self.selectedset.folder][self.selectedset.set] = nil
		self:RefreshDirectory(self.selectedset.folder)
		self.selectedset = nil
	end
end

function KatiaSetManager:OnMoveSet()
	local button = self.wndSet:FindChild("MoveSet")
	if self.moving == nil then
		if self.selectedset == nil or self.selectedset.set == nil then
			FloatText("Please select a set.")
		else
			self.moving = self.selectedset
			button:SetText("Moving...")
			button:SetOpacity(0.5)
			self:RefreshDirectory(self.selectedset.folder)
			self.selectedset = nil
		end
	else
		self.moving = nil
		button:SetText("Move")
		button:SetOpacity(1)
	end
end

function KatiaSetManager:Add(pack)
	if self.selectedset == nil or self.selectedset.set == nil or self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		return
	end
	if pack == nil then
		local selDecor = HousingLib.GetResidence():GetSelectedDecor()
		if selDecor == nil then
			FloatText("Select a decor to add")
			return
		end
		table.insert(self.setdirectory[self.selectedset.folder][self.selectedset.set], Utils:DecorToPack(selDecor))
	else
		table.insert(self.setdirectory[self.selectedset.folder][self.selectedset.set], pack)
	end
	self:Refresh()
end

function KatiaSetManager:AddAll()
	if self.selectedset == nil or self.selectedset.set == nil or self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		return
	end
	local everything = HousingLib.GetResidence():GetPlacedDecorList()
	for i, dec in pairs(everything) do
		local pack = Utils:DecorToPack(dec)
		if Apollo.IsShiftKeyDown() then
			if pack.Y < -60.63 then
				table.insert(self.setdirectory[self.selectedset.folder][self.selectedset.set], Utils:DecorToPack(dec))
			end
		elseif Apollo.IsControlKeyDown() then
			if pack.Y > -60.64 then
				table.insert(self.setdirectory[self.selectedset.folder][self.selectedset.set], Utils:DecorToPack(dec))
			end
		else
			table.insert(self.setdirectory[self.selectedset.folder][self.selectedset.set], Utils:DecorToPack(dec))
		end
	end
	self:Refresh()
end

function KatiaSetManager:AddLinkedSet()
	if self.selectedset == nil or self.selectedset.set == nil or self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		return
	end
	local root = HousingLib.GetResidence():GetSelectedDecor()
	if root == nil then
		FloatText("No decor selected.")
		return
	end
	self:AddPlusChildren(root)
	self:Refresh()
end

-- Recursive helper for adding linked sets
function KatiaSetManager:AddPlusChildren(node)
	table.insert(self.setdirectory[self.selectedset.folder][self.selectedset.set], Utils:DecorToPack(node))
	local children = node:GetChildren()
	if children ~= nil then
		for i, j in pairs(node:GetChildren()) do
			self:AddPlusChildren(j, set)
		end
	end
end

function KatiaSetManager:Remove()
	if self.selectedset == nil or self.selectedset.set == nil or self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		return
	end
	if self.selected == nil then
		self:FloatText("No set item selected")
		return
	end
	if self.selected <= #(self.setdirectory[self.selectedset.folder][self.selectedset.set]) then
		table.remove(self.setdirectory[self.selectedset.folder][self.selectedset.set], self.selected)
	end
	self.selected = nil
	self:Refresh()
end

function KatiaSetManager:Clear(set)
	if self.selectedset == nil or self.selectedset.set == nil or self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		return
	end
	self.setdirectory[self.selectedset.folder][self.selectedset.set] = nil
	self.selected = nil
	self:Refresh()
end

-- Print out what is needed to be able to place a set
function KatiaSetManager:Audit(set)
	local colorNames = {[0] = ""}
	for _, option in ipairs(HousingLib.GetDecorColorOptions()) do
		colorNames[option.id] = "(" .. option.strName .. ")"
	end
	local deColor = Apollo.IsShiftKeyDown()
	
	if self.selectedset == nil or self.selectedset.set == nil or self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		return
	end

	-- How much of everything does the set need?
	local needed = {}
	for i, pack in pairs(self.setdirectory[self.selectedset.folder][self.selectedset.set]) do
		if deColor then
			if needed[pack.N] == nil then
				needed[pack.N] = 1
			else
				needed[pack.N] = needed[pack.N] + 1
			end
		else
			if not pack.C then pack.C = 0 end
			if needed[pack.N] == nil then needed[pack.N] = {} end
			if needed[pack.N][pack.C] == nil then
				needed[pack.N][pack.C] = 1
			else
				needed[pack.N][pack.C] = needed[pack.N][pack.C] + 1
			end
		end
	end

	-- Subtract what we have in crate
	local owned = HousingLib.GetResidence():GetDecorCrateList()
	for i, decinfo in pairs(owned) do
		if needed[decinfo.strName] ~= nil then
			if type(needed[decinfo.strName]) == "number" then
				needed[decinfo.strName] = needed[decinfo.strName] - decinfo.nCount
				if needed[decinfo.strName] <= 0 then
					needed[decinfo.strName] = nil
				end
			else
				for _, specific in ipairs(decinfo.tDecorItems) do
					if needed[decinfo.strName][specific.idColorShift] ~= nil then
						needed[decinfo.strName][specific.idColorShift] = needed[decinfo.strName][specific.idColorShift] - 1
						if needed[decinfo.strName][specific.idColorShift] <= 0 then
							needed[decinfo.strName][specific.idColorShift] = nil
						end
					end
				end
			end
		end
	end

	-- Map out what the vendor can provide
	local vendorlist = HousingLib.GetDecorCatalogList()
	local vendorcosts = {}
	local vendortypes = {}
	for i, decinfo in pairs(vendorlist) do
		vendorcosts[decinfo.strName] = decinfo.nCost
		vendortypes[decinfo.strName] = decinfo.eCurrencyType
	end

	-- Print out what can't be covered by vendor, tally up what can
	self.wndShare:FindChild("Code"):SetText("")
	local totalcost = 0
	local totalrenown = 0
	Print("To cover everything not in your crate, you need:")
	Print("--------------------------------------------------------")
	for name, amount in pairs(needed) do
		if type(amount) == "number" then
			if vendorcosts[name] == nil then
				Print("x" .. amount .. " " .. name)
				self.wndShare:FindChild("Code"):SetText(self.wndShare:FindChild("Code"):GetText() .. "\nx" .. amount .. " " .. name)
			elseif vendortypes[name] == 1 then
				totalcost = totalcost + (amount * vendorcosts[name])
			else
				totalrenown = totalrenown + (amount * vendorcosts[name])
			end
		else
			for color, cAmount in pairs(amount) do
				if color > 0 or vendorcosts[name] == nil then
					Print("x" .. cAmount .. " " .. name .. " " .. colorNames[color])
				elseif vendortypes[name] == 1 then
					totalcost = totalcost + (cAmount * vendorcosts[name])
				else
					totalrenown = totalrenown + (cAmount * vendorcosts[name])
				end
			end
		end
	end

	-- Pretty print the vendor costs
	local plat = math.floor(totalcost / 1000000)
	local gold = math.floor(totalcost / 10000)
	local silver = math.floor(totalcost / 100)
	local moneystring = ""
	if plat > 0 then
		moneystring = plat .. "p "
	end
	if gold > 0 then
		moneystring = moneystring .. (gold % 100) .. "g "
	end
	if silver > 0 then
		moneystring = moneystring .. (silver % 100) .. "s "
	end
	moneystring = moneystring .. (totalcost % 100) .. "c"
	
	Print("Money: " .. moneystring)
	Print("Renown: " .. totalrenown)
end

function KatiaSetManager:OnDiff()
	local fromslot = tonumber(self.wndMain:FindChild("From"):GetText())
	local toslot = tonumber(self.wndMain:FindChild("To"):GetText())
	self:Diff(fromslot, toslot)
end

function KatiaSetManager:OnAverage()
	local fromslot = tonumber(self.wndMain:FindChild("From"):GetText())
	local toslot = tonumber(self.wndMain:FindChild("To"):GetText())
	self:Average(fromslot, toslot)
end

function KatiaSetManager:OnAdd(wndHandler, wndControl, eMouseButton)
	if self.selectedset == nil or self.selectedset.set == nil then
		return
	end
	if self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		self.setdirectory[self.selectedset.folder][self.selectedset.set] = {}
	end
	self:Add()
end

function KatiaSetManager:OnAddAll(wndHandler, wndControl, eMouseButton)
	if self.selectedset == nil or self.selectedset.set == nil then
		return
	end
	if self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		self.setdirectory[self.selectedset.folder][self.selectedset.set] = {}
	end
	self:AddAll()
end

function KatiaSetManager:OnAddLinkedSet(wndHandler, wndControl, eMouseButton)
	if self.selectedset == nil or self.selectedset.set == nil then
		return
	end
	if self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		self.setdirectory[self.selectedset.folder][self.selectedset.set] = {}
	end
	self:AddLinkedSet()
end

function KatiaSetManager:OnReLoc(wndHandler, wndControl, eMouseButton)
	self:ReLoc()
end

function KatiaSetManager:OnPlaceAll(wndHandler, wndControl, eMouseButton)
	self:PlaceAll(false)
end

function KatiaSetManager:OnPlaceAllLink(wndHandler, wndControl, eMouseButton)
	self:PlaceAll(true)
end

function KatiaSetManager:OnSetSelect(wndHandler, wndControl, eMouseButton)
	local i = wndHandler:GetData().index
	if eMouseButton == GameLib.CodeEnumInputMouse.Left then
		if Apollo.IsShiftKeyDown() then
			local pack = table.remove(self.setdirectory[self.selectedset.folder][self.selectedset.set], i)
			table.insert(self.setdirectory[self.selectedset.folder][self.selectedset.set], 1, pack)
			self.selected = 1
		else
			self.selected = i
			Utils:ClonePack(self.setdirectory[self.selectedset.folder][self.selectedset.set][i], true)
		end
		self:Refresh()
		DecorEditor:Refresh()
	elseif eMouseButton == GameLib.CodeEnumInputMouse.Right then
		local newDec = Utils:ClonePack(self.setdirectory[self.selectedset.folder][self.selectedset.set][i], true)
		newDec:Place()
	end
end

function KatiaSetManager:OnRemove( wndHandler, wndControl, eMouseButton )
	self:Remove()
end

function KatiaSetManager:OnClear( wndHandler, wndControl, eMouseButton )
	self:Clear()
end

function KatiaSetManager:OnAudit()
	self:Audit()
end

-- Move the current decor set to the player's position
function KatiaSetManager:ReLoc()
	if self.selectedset == nil or self.selectedset.set == nil or self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		return
	end
	if self.setdirectory[self.selectedset.folder][self.selectedset.set][1] == nil then
		return
	end
	local tPos = GameLib.GetPlayerUnit():GetPosition()
	local newPos = Utils:PlayerToDecorPos(tPos)
	local diffX = newPos.X - self.setdirectory[self.selectedset.folder][self.selectedset.set][1].X
	local diffY = newPos.Y - self.setdirectory[self.selectedset.folder][self.selectedset.set][1].Y
	local diffZ = newPos.Z - self.setdirectory[self.selectedset.folder][self.selectedset.set][1].Z
	for i, d in pairs(self.setdirectory[self.selectedset.folder][self.selectedset.set]) do
		d.X = d.X + diffX
		d.Y = d.Y + diffY
		d.Z = d.Z + diffZ
	end
end

function KatiaSetManager:OnTodoTimer()
	Batcher:OnTodo()
end

function KatiaSetManager:PlaceAll(bLink)
	if self.selectedset == nil or self.selectedset.set == nil or self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		return
	end
	local uncolored = Apollo.IsShiftKeyDown()

	local todo = nil
	if bLink then
		todo = Batcher:Prepare(
			function (_, ch)
				local newDec = Utils:ClonePack(ch, uncolored)
				if newDec == nil then
					self.singletonTimer = ApolloTimer.Create(0.5, false, "OnTodoTimer", self)
				elseif not newDec:ValidatePlacement() then
					newDec:CancelTransform()
					self.singletonTimer = ApolloTimer.Create(0.5, false, "OnTodoTimer", self)
				else
					newDec:Place()
				end
			end,
			function (_, dec)
				if self.parent == nil then
					self.parent = dec
				elseif dec ~= nil then
					dec:Link(self.parent)
				end
			end,
			function (_, dec)
				self.singletonTimer = ApolloTimer.Create(0.5, false, "FinalSelect", self)
			end
		)
	else
		todo = Batcher:Prepare(
			function (_, ch)
				local newDec = Utils:ClonePack(ch, uncolored)
				if newDec == nil then
					self.singletonTimer = ApolloTimer.Create(0.5, false, "OnTodoTimer", self)
				elseif not newDec:ValidatePlacement() then
					newDec:CancelTransform()
					self.singletonTimer = ApolloTimer.Create(0.5, false, "OnTodoTimer", self)
				else
					newDec:Place()
				end
			end,
			nil,
			nil
		)
	end

	if todo == nil then return end

	for i, ch in pairs(self.setdirectory[self.selectedset.folder][self.selectedset.set]) do
		table.insert(todo, ch)
	end
	Batcher:StartDecorDriven()
end

function KatiaSetManager:FinalSelect()
	self.parent:Select()
	self.parent = nil
	DecorEditor:Refresh()
end


-----------------------------------------------------------------------------------------------
-- Initialization of CassPkg to encode and decode tables with base64
-- Credit to "Casstiel" on official wildstar forums
-----------------------------------------------------------------------------------------------
-- from http://help.interfaceware.com/kb/112
function KatiaSetManager:SaveTable(Table)
   local savedTables = {} -- used to record tables that have been saved, so that we do not go into an infinite recursion
   local outFuncs = {
      ['string']  = function(value) return string.format("%q",value) end;
      ['boolean'] = function(value) if (value) then return 'true' else return 'false' end end;
      ['number']  = function(value) if (math.floor(value) == value) then return string.format('%d',math.floor(value)) else return string.format('%.3f',value) end end;
      ['userdata']  = function(value) return 'nil' end;
   }
   local outFuncsMeta = {
      __index = function(t,k) error('Invalid Type For SaveTable: '..k ) end      
   }
   setmetatable(outFuncs,outFuncsMeta)
   local tableOut = function(value)
      if (savedTables[value]) then
         error('There is a cyclical reference (table value referencing another table value) in this set.');
      end
      local outValue = function(value) return outFuncs[type(value)](value) end
      local out = '{'
      for i,v in pairs(value) do out = out..'['..outValue(i)..']='..outValue(v)..',' end
      savedTables[value] = true; --record that it has already been saved
      return out..'}'
   end
   outFuncs['table'] = tableOut;
   --return self:ascii_encode(tableOut(Table))
   return tableOut(Table)
end

function KatiaSetManager:LoadTable(Input)
   -- note that this does not enforce anything, for simplicity
   --local decoded = self:ascii_decode(Input)
   return assert(loadstring('return '.. Input ))()
end

function KatiaSetManager:Simplify(tSet)
    tSimpleData = {}

	local tStringMap = {}
	local tNameHeaderData = {}
	local index = 1
	for idx = 1, #tSet do
		if tStringMap[tSet[idx].N] == nil then
			tStringMap[tSet[idx].N] = index
			tNameHeaderData[index] = tSet[idx].N
			index = index + 1
		end
	end
    
    tSimpleData.name = "KBT convert"
	tSimpleData.text = tNameHeaderData
	tSimpleData.plugs = {}
	
	tSimpleData.extOptions = {}
	tSimpleData.intOptions = {}
	
	tSimpleData.decor = {}
    for idx = 1, #tSet do
        tSimpleData.decor[idx] = {}
        tSimpleData.decor[idx].n = tStringMap[tSet[idx].N]
        tSimpleData.decor[idx].x = tSet[idx].X
        tSimpleData.decor[idx].y = tSet[idx].Y
        tSimpleData.decor[idx].z = tSet[idx].Z
		if math.abs(tSet[idx].P) >= 0.001 then
        	tSimpleData.decor[idx].p = tSet[idx].P
		end
		if math.abs(tSet[idx].R) >= 0.001 then
        	tSimpleData.decor[idx].r = tSet[idx].R
		end
		if math.abs(tSet[idx].Yaw) >= 0.001 then
        	tSimpleData.decor[idx].ya = tSet[idx].Yaw
		end
		if math.abs(tSet[idx].S - 1.0) >= 0.001 then
        	tSimpleData.decor[idx].s = tSet[idx].S
		end
    end
    
    return tSimpleData
end

function KatiaSetManager:OnToDSM()
	self.wndShare:FindChild("Code"):SetText("")
	if self.selectedset == nil or self.selectedset.set == nil or self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		return
	end
	local strEncodedSet = self:SaveTable(self:Simplify(self.setdirectory[self.selectedset.folder][self.selectedset.set]))
	if string.len(strEncodedSet) < 32000 then
		self.wndShare:FindChild("Code"):SetText(strEncodedSet)
	else
		self.wndShare:FindChild("Code"):SetText("Set too large to share.")
	end
end

function KatiaSetManager:OnFromDSM()
	local code = self.wndShare:FindChild("Code"):GetText()
	if self.selectedset == nil or self.selectedset.set == nil or self.setdirectory[self.selectedset.folder][self.selectedset.set] == nil then
		return
	end
	local tSimpleData = self:LoadTable(code)
	local tNameHeaderData = tSimpleData.text
  
    for idx = 1, #tSimpleData.decor do
		local newDec = {}
		newDec.N = tNameHeaderData[tSimpleData.decor[idx].n]
        newDec.X = tSimpleData.decor[idx].x
        newDec.Y = tSimpleData.decor[idx].y
        newDec.Z = tSimpleData.decor[idx].z
		if tSimpleData.decor[idx].p ~= nil then
        	newDec.P = tSimpleData.decor[idx].p
		else
			newDec.P = 0.0
		end
		if tSimpleData.decor[idx].r ~= nil then
        	newDec.R = tSimpleData.decor[idx].r
		else
			newDec.R = 0.0
		end
		if tSimpleData.decor[idx].ya ~= nil then
        	newDec.Yaw = tSimpleData.decor[idx].ya
		else
			newDec.Yaw = 0.0
		end
		if tSimpleData.decor[idx].s ~= nil then
        	newDec.S = tSimpleData.decor[idx].s
		else
			newDec.S = 1.0
		end
		table.insert(self.setdirectory[self.selectedset.folder][self.selectedset.set], newDec)
    end
	self:Refresh()
end

function KatiaSetManager:OnShare()
	self.wndShare:Invoke()
	self:OnToDSM()
end

function KatiaSetManager:OnCancelShare()
	self.wndShare:Close()
end


Apollo.RegisterPackage(KatiaSetManager, MAJOR, MINOR, {})