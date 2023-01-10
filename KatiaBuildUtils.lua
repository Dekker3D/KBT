local MAJOR, MINOR = "Module:KatiaBuildUtils-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local KatiaBuildUtils = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
KatiaBuildUtils.null = setmetatable ({}, {
  __toinn = function () return "null" end
})
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

-- Check if all strings in matchers are in check
local function CheckMatchers(check, matchers)
	for _,i in pairs(matchers) do
		if string.find(string.lower(check), string.lower(i)) == nil then
			return false
		end
	end
	return true
end

function KatiaBuildUtils:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("KatiaBuildUtils.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function KatiaBuildUtils:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
		self.wndBack = Apollo.LoadForm(self.xmlDoc, "Background", "InWorldHudStratum", self)
		if self.wndBack == nil then
			Apollo.AddAddonErrorText(self, "Could not load the background window for some reason.")
			return
		end
	end
end

-- Save the info of a decor item into a pack
function KatiaBuildUtils:DecorToPack(decor)
	local tDecorInfo = decor:GetDecorIconInfo()
	if tDecorInfo == nil then
		return nil
	end
	local newPack = {}
	newPack.N = decor:GetName()
	newPack.I = decor:GetDecorInfoId()
	newPack.X = tDecorInfo.fWorldPosX
	newPack.Y = tDecorInfo.fWorldPosY
	newPack.Z = tDecorInfo.fWorldPosZ
	newPack.S = tDecorInfo.fScaleCurrent
	newPack.P = tDecorInfo.fPitch
	newPack.R = tDecorInfo.fRoll
	newPack.Yaw = tDecorInfo.fYaw
	newPack.C = decor:GetSavedDecorColor()
	
	return newPack
end

-- Preview a pack from crate or vendor
function KatiaBuildUtils:ClonePack(pack, neutralize)
	local colorMatch
	if neutralize or not pack.C then
		colorMatch = 0
	else
		colorMatch = pack.C
	end
	colorMatch = nil
	-- resolve matchers if necessary
	if pack.matchers ~= nil then
		local tDecorCrateList = HousingLib.GetResidence():GetDecorCrateList()
		if tDecorCrateList ~= nil then
			for idx = 1, #tDecorCrateList do
				local tCratedDecorData = tDecorCrateList[idx]
				if (pack.N == nil or string.len(pack.N) > string.len(tCratedDecorData.strName)) and
					CheckMatchers(tCratedDecorData.strName, pack.matchers) then
					pack.N = tCratedDecorData.strName
				end
			end
		end
		local tDecorVendorList = HousingLib.GetDecorCatalogList()
		if tDecorVendorList ~= nil then
			for idx = 1, #tDecorVendorList do
				local tVendorDecorData = tDecorVendorList[idx]
				if (pack.N == nil or string.len(pack.N) > string.len(tVendorDecorData.strName)) and
					CheckMatchers(tVendorDecorData.strName, pack.matchers) then
					pack.N = tVendorDecorData.strName
				end
			end
		end
	end

	-- Check crate first
	local foundMismatch = false
	local tDecorCrateList = HousingLib.GetResidence():GetDecorCrateList()
	if tDecorCrateList ~= nil then
		for idx = 1, #tDecorCrateList do
			local tCratedDecorData = tDecorCrateList[idx]
			if pack.N ~= nil and tCratedDecorData.strName == pack.N then
				for _, specific in pairs(tCratedDecorData.tDecorItems) do
					if colorMatch == nil or specific.idColorShift == colorMatch then
						local dec = HousingLib.PreviewCrateDecorAtLocation(
									specific.nDecorId,
									specific.nDecorIdHi,
									pack.X, pack.Y, pack.Z,
									pack.P, pack.R, pack.Yaw,
									pack.S)
						local tDecorInfo = dec:GetDecorIconInfo()
						local newX = tDecorInfo.fWorldPosX
						local newY = tDecorInfo.fWorldPosY
						local newZ = tDecorInfo.fWorldPosZ
						-- Deshift if necessary
						dec = HousingLib.PreviewCrateDecorAtLocation(
									specific.nDecorId,
									specific.nDecorIdHi,
									2*pack.X - newX, 2*pack.Y - newY, 2*pack.Z  - newZ,
									pack.P, pack.R, pack.Yaw,
									pack.S)
						return dec
					else
						foundMismatch = true
					end
				end
			end
		end
	end

	
	-- Go to vendor otherwise
	if colorMatch == 0 or colorMatch == nil then
		local tDecorVendorList = HousingLib.GetDecorCatalogList()
		if tDecorVendorList ~= nil then
			for idx = 1, #tDecorVendorList do
				local tVendorDecorData = tDecorVendorList[idx]
				if pack.N ~= nil then -- vendor check was here
					local dec = HousingLib.PreviewVendorDecorAtLocation(pack.I,
								pack.X, pack.Y, pack.Z,
								pack.P, pack.R, pack.Yaw,
								pack.S)
					local tDecorInfo = dec:GetDecorIconInfo()
					local newX = tDecorInfo.fWorldPosX
					local newY = tDecorInfo.fWorldPosY
					local newZ = tDecorInfo.fWorldPosZ
					-- Deshift if necessary
					dec = HousingLib.PreviewVendorDecorAtLocation(pack.I,
								2*pack.X - newX, 2*pack.Y - newY, 2*pack.Z  - newZ,
								pack.P, pack.R, pack.Yaw,
								pack.S)
					return dec
				end
			end
		end
	end

	if foundMismatch then
		FloatText(string.format("No matching colors found for %s", pack.N))
	elseif pack.N ~= nil then
		FloatText(string.format("%s not available in crate or vendor", pack.N))
	else
		FloatText("No matches found")
	end

	return nil
end

-- Conversion between player coordinates and decor coordinates
local world_offsets = {
	[1136] = { -- non community housing plot
		x = 1472,
		y = -715,
		z = 1440
	},
	[1265] = { -- community common area
		x = 528,
		y = -715,
		z = -464
	},
	-- community plots below
	[1161] = {
		x = 352,
		y = -715,
		z = -640
	},
	[1162] = {
		x = 640,
		y = -715,
		z = -640
	},
	[1163] = {
		x = 224,
		y = -715,
		z = -256
	},
	[1164] = {
		x = 512,
		y = -715,
		z = -256
	},
	[1165] = {
		x = 800,
		y = -715,
		z = -256
	},
}

function KatiaBuildUtils:DecorToPlayerPos(x, y, z)
	local offsets = world_offsets[GameLib.GetCurrentZoneId()]
	local result = {}
	result.x = z + offsets.x
	result.y = y + offsets.y
	result.z = (-1 * x) + offsets.z
	return result
end

function KatiaBuildUtils:PlayerToDecorPos(tPos)
	local offsets = world_offsets[GameLib.GetCurrentZoneId()]
	local result = {}
	result.X = -1 * (tPos.z - offsets.z)
	result.Y = tPos.y - offsets.y
	result.Z = tPos.x - offsets.x
	return result
end

-- Pull a matching item from crate/vendor and place it above player head
function KatiaBuildUtils:Summon(strArg)
	local tPos = GameLib.GetPlayerUnit():GetPosition()
	local dPos = self:PlayerToDecorPos(tPos)
	dPos.Y = dPos.Y + 3
	dPos.P = 0
	dPos.R = 0
	dPos.Yaw = 0
	dPos.S = 1
	dPos.matchers = {}
	string.gsub(strArg, "([^ ]+)", function(c) table.insert(dPos.matchers, c) end)
	local dec = self:ClonePack(dPos)
	Event_FireGenericEvent("HousingFreePlaceDecorQuery", dec)
end

-- Round all stats to the nearest hundredth
function KatiaBuildUtils:Round()
	local res = HousingLib.GetResidence()
	if res == nil then return end
	local selDecor = res:GetSelectedDecor()
	if selDecor == nil then return end
	local pack = self:DecorToPack(selDecor)
	selDecor:SetPosition(ToHundredth(pack.X), ToHundredth(pack.Y), ToHundredth(pack.Z))
	selDecor:SetRotation(ToHundredth(pack.P), ToHundredth(pack.R), ToHundredth(pack.Yaw))
	selDecor:SetScale(ToHundredth(pack.S))
end

-- Draw a line to selected decor on screen
function KatiaBuildUtils:Locate()
	local res = HousingLib.GetResidence()
	if res == nil then return end
	local selDecor = res:GetSelectedDecor()
	if selDecor == nil then
		self:FloatText("No decor selected")
		return
	end
	local pack = self:DecorToPack(selDecor)
	self.dPos = self:DecorToPlayerPos(pack.X, pack.Y, pack.Z)
	self.count = 100
	self.locateTimer = ApolloTimer.Create(0.03, true, "OnLocateTick", self)
end

function KatiaBuildUtils:OnLocateTick()
	self.wndBack:DestroyAllPixies()
	self.count = self.count - 1
	if self.dPos == nil or self.count <= 0 then
		self.locateTimer:Stop()
		return
	end
	local player = GameLib.GetPlayerUnit()
	if player == nil then
		return
	end
	local pPos = player:GetPosition()
	local pScreen = GameLib.WorldLocToScreenPoint(Vector3.New(pPos.x, pPos.y, pPos.z))
	local dScreen = GameLib.WorldLocToScreenPoint(Vector3.New(self.dPos.x, self.dPos.y, self.dPos.z))

	self.wndBack:AddPixie( {
		bLine = true, fWidth = 2, cr = {a=1,r=1,g=0,b=0},
		loc = { fPoints = { 0, 0, 0, 0 }, nOffsets = { dScreen.x, dScreen.y, pScreen.x, pScreen.y } }
	} )
end

function KatiaBuildUtils:Place()
	local selDecor = HousingLib.GetResidence():GetSelectedDecor()
	if selDecor ~= nil then
		selDecor:Place()
	end
end

function KatiaBuildUtils:Crate()
	local selDecor = HousingLib.GetResidence():GetSelectedDecor()
	if selDecor ~= nil then
		selDecor:Crate()
	end
end

function KatiaBuildUtils:CrateLinkedSet()
	local root = HousingLib.GetResidence():GetSelectedDecor()
	if root == nil then
		self:FloatText("No decor selected.")
		return
	end
	local todo = Batcher:Prepare(
		function (_, dec)
			dec:Crate()
		end,
		nil,
		nil
	)
	if todo == nil then return end
	self:CratePlusChildren(root, todo)
	Batcher:StartDecorDriven()
end

-- Recursive helper for crating linked sets
function KatiaBuildUtils:CratePlusChildren(node, todo)
	local children = node:GetChildren()
	if children ~= nil then
		for i, j in pairs(node:GetChildren()) do
			self:CratePlusChildren(j, todo)
		end
	end
	table.insert(todo, node)
end


Apollo.RegisterPackage(KatiaBuildUtils, MAJOR, MINOR, {})