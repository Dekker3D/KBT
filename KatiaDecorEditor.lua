local MAJOR, MINOR = "Module:KatiaDecorEditor-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local KatiaDecorEditor = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
KatiaDecorEditor.null = setmetatable ({}, {
  __toinn = function () return "null" end
})
local Utils = Apollo.GetPackage("Module:KatiaBuildUtils-1.0").tPackage

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

function KatiaDecorEditor:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("KatiaDecorEditor.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)

	self.HousingAddon = Apollo.GetAddon("Housing")
	Apollo.RegisterEventHandler("HousingFreePlaceDecorQuery", "Refresh", self)
	Apollo.RegisterEventHandler("HousingFreePlaceDecorSelected", "Refresh", self)
	Apollo.RegisterEventHandler("HousingFreePlaceDecorMoving", "Refresh", self)
	Apollo.RegisterEventHandler("HousingFreePlaceDecorSelected", "RefreshColorPreview", self)

	self.queued = {}
end

function KatiaDecorEditor:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndDecor = Apollo.LoadForm(self.xmlDoc, "DecorForm", nil, self)
		if self.wndDecor == nil then
			Apollo.AddAddonErrorText(self, "Could not load the decor window for some reason.")
			return
		end

	    self.wndColor = Apollo.LoadForm(self.xmlDoc, "ColorForm", nil, self)
		if self.wndColor == nil then
			Apollo.AddAddonErrorText(self, "Could not load the color window for some reason.")
			return
		end

	    self.wndDecor:Show(false, true)
	    self.wndColor:Show(false, true)
		if self.bgOpacity ~= nil then
			self.wndDecor:SetBGOpacity(self.bgOpacity)
			self.wndColor:SetBGOpacity(self.bgOpacity)
		end
	end
end

function KatiaDecorEditor:Open()
	self.HousingAddon.wndDecorIconFrame:SetScale(0.0)
	self.wndDecor:Invoke() -- show the window
	self:Refresh()
end

function KatiaDecorEditor:Close()
	self.HousingAddon.wndDecorIconFrame:SetScale(1.0)
	self.wndDecor:Close() -- hide the window
end

function KatiaDecorEditor:SetBGOpacity(value)
	self.bgOpacity = value
	if self.wndDecor ~= nil then
		self.wndDecor:SetBGOpacity(value)
	end
	if self.wndColor ~= nil then
		self.wndColor:SetBGOpacity(value)
	end
end

-- Synchronize the UI to the selected decor
function KatiaDecorEditor:Refresh()
	local res = HousingLib.GetResidence()
	if res == nil then return end
	local selDecor = res:GetSelectedDecor()
	if selDecor == nil then return end
	
	local pack = Utils:DecorToPack(selDecor)
	self.wndDecor:FindChild("PosX"):SetText(string.format("%.2f", pack.X))
	self.wndDecor:FindChild("PosY"):SetText(string.format("%.2f", pack.Y))
	self.wndDecor:FindChild("PosZ"):SetText(string.format("%.2f", pack.Z))
	
	-- Carbine UI swaps Roll and Yaw from code representation, we will match them
	self.wndDecor:FindChild("RotYaw"):SetText(string.format("%.2f", pack.R))
	self.wndDecor:FindChild("RotPitch"):SetText(string.format("%.2f", pack.P))
	self.wndDecor:FindChild("RotRoll"):SetText(string.format("%.2f", pack.Yaw))

	self.wndDecor:FindChild("Scale"):SetText(string.format("%.2f", pack.S))
	self.wndDecor:FindChild("Name"):SetText(pack.N)
end

function KatiaDecorEditor:Target(targetedId, targetedIdHigh)
	self.targetedId = targetedId
	self.targetedIdHigh = targetedIdHigh
	if targetedId == nil then
		self.wndDecor:FindChild("Link"):SetBGColor({a=1,r=1,b=1,g=1})
	else
		self.wndDecor:FindChild("Link"):SetBGColor({a=1,r=0,b=1,g=0})
	end
end

function KatiaDecorEditor:OnPosChange()
	local selDecor = HousingLib.GetResidence():GetSelectedDecor()
	if selDecor == nil then
		return
	end
	
	local x = tonumber(self.wndDecor:FindChild("PosX"):GetText())
	local y = tonumber(self.wndDecor:FindChild("PosY"):GetText())
	local z = tonumber(self.wndDecor:FindChild("PosZ"):GetText())

	if x ~= nil and y ~= nil and z ~= nil then
		local pack = Utils:DecorToPack(selDecor)
		selDecor:SetPosition(x, y, z)
		selDecor:SetRotation(pack.P, pack.R, pack.Yaw)
		selDecor:SetScale(pack.S)
	end
	self:Refresh()
end

function KatiaDecorEditor:OnRotChange()
	local selDecor = HousingLib.GetResidence():GetSelectedDecor()
	if selDecor == nil then
		return
	end

	-- Carbine UI swaps Roll and Yaw from code representation, we will match them
	local pitch = tonumber(self.wndDecor:FindChild("RotPitch"):GetText())
	local roll = tonumber(self.wndDecor:FindChild("RotYaw"):GetText())
	local yaw = tonumber(self.wndDecor:FindChild("RotRoll"):GetText())

	if pitch ~= nil and roll ~= nil and yaw ~= nil then
		local pack = Utils:DecorToPack(selDecor)
		selDecor:SetPosition(pack.X, pack.Y, pack.Z)
		selDecor:SetRotation(pitch, roll, yaw)
		selDecor:SetScale(pack.S)
	end
	self:Refresh()
end

function KatiaDecorEditor:OnScaleChange()
	local selDecor = HousingLib.GetResidence():GetSelectedDecor()
	if selDecor == nil then
		return
	end

	local scale = tonumber(self.wndDecor:FindChild("Scale"):GetText())

	if scale ~= nil then
		local pack = Utils:DecorToPack(selDecor)
		selDecor:SetPosition(pack.X, pack.Y, pack.Z)
		selDecor:SetRotation(pack.P, pack.R, pack.Yaw)
		selDecor:SetScale(scale)
	end
	self:Refresh()
end

local function AlteredAmount()
	local amount = .05
	if Apollo.IsShiftKeyDown() then
		amount = .01
	elseif Apollo.IsControlKeyDown() then
		amount = .5
	elseif Apollo.IsAltKeyDown() then
		amount = 5
	end
	return amount
end

local function AlteredAngle()
	local amount = 5.625
	if Apollo.IsShiftKeyDown() then
		amount = 1.40625
	elseif Apollo.IsControlKeyDown() then
		amount = 22.5
	elseif Apollo.IsAltKeyDown() then
		amount = 90
	end
	return amount
end

function KatiaDecorEditor:OnXDown()
	IncrementF(self.wndDecor, "PosX", -1 * AlteredAmount())
	self:OnPosChange()
end

function KatiaDecorEditor:OnXUp()
	IncrementF(self.wndDecor, "PosX", AlteredAmount())
	self:OnPosChange()
end

function KatiaDecorEditor:OnYDown()
	IncrementF(self.wndDecor, "PosY", -1 * AlteredAmount())
	self:OnPosChange()
end

function KatiaDecorEditor:OnYUp()
	IncrementF(self.wndDecor, "PosY", AlteredAmount())
	self:OnPosChange()
end

function KatiaDecorEditor:OnZDown()
	IncrementF(self.wndDecor, "PosZ", -1 * AlteredAmount())
	self:OnPosChange()
end

function KatiaDecorEditor:OnZUp()
	IncrementF(self.wndDecor, "PosZ", AlteredAmount())
	self:OnPosChange()
end

function KatiaDecorEditor:OnYawDown()
	IncrementF(self.wndDecor, "RotYaw", -1 * AlteredAngle())
	self:OnRotChange()
end

function KatiaDecorEditor:OnYawUp()
	IncrementF(self.wndDecor, "RotYaw", AlteredAngle())
	self:OnRotChange()
end

function KatiaDecorEditor:OnPitchDown()
	IncrementF(self.wndDecor, "RotPitch", -1 * AlteredAngle())
	self:OnRotChange()
end

function KatiaDecorEditor:OnPitchUp()
	IncrementF(self.wndDecor, "RotPitch", AlteredAngle())
	self:OnRotChange()
end

function KatiaDecorEditor:OnRollDown()
	IncrementF(self.wndDecor, "RotRoll", -1 * AlteredAngle())
	self:OnRotChange()
end

function KatiaDecorEditor:OnRollUp()
	IncrementF(self.wndDecor, "RotRoll", AlteredAngle())
	self:OnRotChange()
end

function KatiaDecorEditor:OnScaleDown()
	IncrementF(self.wndDecor, "Scale", -1 * AlteredAmount())
	self:OnScaleChange()
end

function KatiaDecorEditor:OnScaleUp()
	IncrementF(self.wndDecor, "Scale", AlteredAmount())
	self:OnScaleChange()
end

function KatiaDecorEditor:OnWorld()
	HousingLib.GetResidence():SetCustomizationMode(HousingLib.ResidenceCustomizationMode.Advanced)
	HousingLib.SetControlMode(HousingLib.DecorControlMode.Global)
end

function KatiaDecorEditor:OnObject()
	HousingLib.GetResidence():SetCustomizationMode(HousingLib.ResidenceCustomizationMode.Advanced)
	HousingLib.SetControlMode(HousingLib.DecorControlMode.Local)
end

function KatiaDecorEditor:OnDrag()
	HousingLib.SetControlMode(HousingLib.DecorControlMode.Global)
	HousingLib.GetResidence():SetCustomizationMode(HousingLib.ResidenceCustomizationMode.Simple)
end

function KatiaDecorEditor:OnLink()
	local selDecor = HousingLib.GetResidence():GetSelectedDecor()
	if selDecor == nil or selDecor:IsPreview() then
		FloatText("No linkable decor selected")
		return
	end
	
	if Apollo.IsShiftKeyDown() then
		selDecor:Unlink()
	elseif Apollo.IsControlKeyDown() then
		selDecor:UnlinkAllChildren()
	elseif self.targetedId ~= nil then
		self:LinkToTarget()
	else
		self.HousingAddon:OnFreePlaceLinkBtn()
	end
end

function KatiaDecorEditor:LinkToTarget()
	local targeted = HousingLib.GetResidence():GetDecorById(self.targetedId, self.targetedIdHigh)
	if targeted == nil then
		FloatText("No decor targeted.")
		return
	end
	local selDecor = HousingLib.GetResidence():GetSelectedDecor()
	if selDecor == nil or selDecor:IsPreview() then
		FloatText("No linkable decor selected")
		return
	end
	selDecor:Link(targeted)
end

function KatiaDecorEditor:OnLocate()
	Utils:Locate()
end

function KatiaDecorEditor:OnDirectMove(wndHandler, wndControl)
	local res = HousingLib.GetResidence()
	if res == nil then return end
	local selDecor = res:GetSelectedDecor()
	if selDecor == nil then return end

	local pack = Utils:DecorToPack(selDecor)
	if wndControl == self.wndDecor:FindChild("MoveForward") then
		selDecor:Translate(AlteredAmount(), 0, 0)
		selDecor:SetRotation(pack.P, pack.R, pack.Yaw)
		selDecor:SetScale(pack.S)
	elseif wndControl == self.wndDecor:FindChild("MoveBack") then
		selDecor:Translate(-1 * AlteredAmount(), 0, 0)
		selDecor:SetRotation(pack.P, pack.R, pack.Yaw)
		selDecor:SetScale(pack.S)
	elseif wndControl == self.wndDecor:FindChild("MoveLeft") then
		selDecor:Translate(0, 0, -1*AlteredAmount())
		selDecor:SetRotation(pack.P, pack.R, pack.Yaw)
		selDecor:SetScale(pack.S)
	elseif wndControl == self.wndDecor:FindChild("MoveRight") then
		selDecor:Translate(0, 0, AlteredAmount())
		selDecor:SetRotation(pack.P, pack.R, pack.Yaw)
		selDecor:SetScale(pack.S)
	elseif wndControl == self.wndDecor:FindChild("MoveUp") then
		selDecor:Translate(0, AlteredAmount(), 0)
		selDecor:SetRotation(pack.P, pack.R, pack.Yaw)
		selDecor:SetScale(pack.S)
	elseif wndControl == self.wndDecor:FindChild("MoveDown") then
		selDecor:Translate(0, -1*AlteredAmount(), 0)
		selDecor:SetRotation(pack.P, pack.R, pack.Yaw)
		selDecor:SetScale(pack.S)
	elseif wndControl == self.wndDecor:FindChild("RollCounter") then
		selDecor:Rotate(0, math.rad(AlteredAngle()), 0)
		selDecor:SetPosition(pack.X, pack.Y, pack.Z)
		selDecor:SetScale(pack.S)
	elseif wndControl == self.wndDecor:FindChild("RollClock") then
		selDecor:Rotate(0, -1*math.rad(AlteredAngle()), 0)
		selDecor:SetPosition(pack.X, pack.Y, pack.Z)
		selDecor:SetScale(pack.S)
	elseif wndControl == self.wndDecor:FindChild("TiltUp") then
		selDecor:Rotate(0, 0, math.rad(AlteredAngle()))
		selDecor:SetPosition(pack.X, pack.Y, pack.Z)
		selDecor:SetScale(pack.S)
	elseif wndControl == self.wndDecor:FindChild("TiltDown") then
		selDecor:Rotate(0, 0, -1*math.rad(AlteredAngle()))
		selDecor:SetPosition(pack.X, pack.Y, pack.Z)
		selDecor:SetScale(pack.S)
	elseif wndControl == self.wndDecor:FindChild("TiltLeft") then
		selDecor:Rotate(math.rad(AlteredAngle()), 0, 0)
		selDecor:SetPosition(pack.X, pack.Y, pack.Z)
		selDecor:SetScale(pack.S)
	elseif wndControl == self.wndDecor:FindChild("TiltRight") then
		selDecor:Rotate(-1*math.rad(AlteredAngle()), 0, 0)
		selDecor:SetPosition(pack.X, pack.Y, pack.Z)
		selDecor:SetScale(pack.S)
	end
end

function KatiaDecorEditor:ToggleColorCost()
	local dec = HousingLib.GetResidence():GetSelectedDecor()
	if dec == nil then return end
	self:MakeSwatches(dec)
end

function KatiaDecorEditor:RefreshColorPreview(dec)
	self.wndColor:FindChild("SelectedModel"):SetDecorInfo(dec:GetDecorInfoId())
	self.wndColor:FindChild("SelectedModel"):SetDecorColor(dec:GetDecorColor())
	self:MakeSwatches(dec)
end

function KatiaDecorEditor:MakeSwatches(dec)
	local arColorShiftOptions = HousingLib.GetDecorColorOptions()
	local wndList = self.wndColor:FindChild("List")
	wndList:DestroyChildren()
	local bToken = self.wndColor:FindChild("UseToken"):IsChecked()
	for i, tColor in pairs(arColorShiftOptions) do
		local wndListItem = Apollo.LoadForm(self.xmlDoc, "ColorButtonItem", wndList, self)
		local wndButton = wndListItem:FindChild("ColorPick")
		local wndSwatch = wndButton:FindChild("Swatch")
		wndSwatch:SetSprite(tColor.strPreviewSwatch)
		wndButton:SetActionData(GameLib.CodeEnumConfirmButtonType.DecorColorShift, dec, bToken)
		wndButton:SetData(tColor.id)
		if tColor.id == dec:GetSavedDecorColor() then
			wndButton:SetBGColor({a=1,r=1,b=0,g=0})
		end
	end
	Apollo.LoadForm(self.xmlDoc, "ColorButtonResetItem", wndList, self)
	wndList:ArrangeChildrenTiles()
end

function KatiaDecorEditor:OnColorSelect(wndHandler, wndControl)
	local dec = HousingLib.GetResidence():GetSelectedDecor()
	if dec == nil then return end
	dec:SetColor(wndHandler:GetData())
	self.wndColor:FindChild("SelectedModel"):SetDecorColor(dec:GetDecorColor())
end

function KatiaDecorEditor:OnColorDeselect(wndHandler, wndControl)
	local dec = HousingLib.GetResidence():GetSelectedDecor()
	if dec == nil then return end
	dec:RevertDecorColor()
	self.wndColor:FindChild("SelectedModel"):SetDecorColor(dec:GetDecorColor())
end

function KatiaDecorEditor:OnClearColor()
	local dec = HousingLib.GetResidence():GetSelectedDecor()
	if dec == nil then return end
	dec:SetColor(0)
	self.wndColor:FindChild("SelectedModel"):SetDecorColor(0)
end

--TODO fix this when finder is refactored
function KatiaDecorEditor:OnQueueFinder()
	local wndList = Apollo.GetPackage("Module:KatiaDecorFinder-1.0").tPackage.wndFinder:FindChild("List")
	for _, item in pairs(wndList:GetChildren()) do
		local data = item:GetData()
		table.insert(self.queued, data)
	end
	self:RefreshQueue()
end

function KatiaDecorEditor:RefreshQueue()
	local wndQueue = self.wndColor:FindChild("Queue")
	wndQueue:DestroyChildren()
	for _, id in pairs(self.queued) do
		local wndQueueItem = Apollo.LoadForm(self.xmlDoc, "QueueItem", wndQueue, self)
		wndQueueItem:SetText(HousingLib.GetResidence():GetDecorById(id.low, id.high):GetName())
	end
	wndQueue:ArrangeChildrenVert()
end

function KatiaDecorEditor:OnColorStart()
	if #self.queued >= 1 then
		local dec = HousingLib.GetResidence():GetDecorById(self.queued[1].low, self.queued[1].high)
		if dec ~= nil then
			dec:Select()
			Utils:Locate()
			self:RefreshColorPreview(dec)
		end
		table.remove(self.queued, 1)
		self:RefreshQueue()
	end
end

function KatiaDecorEditor:OnQueueLS()
	local dec = HousingLib.GetResidence():GetSelectedDecor()
	if dec == nil then
		FloatText("Select parent decor")
		return
	end
	self:QueuePlusChildren(dec)
	self:RefreshQueue()
end

function KatiaDecorEditor:QueuePlusChildren(node)
	local val = {}
	val.low, val.high = node:GetId()
	table.insert(self.queued, val)
	local children = node:GetChildren()
	if children ~= nil then
		for i, j in pairs(children) do
			self:QueuePlusChildren(j)
		end
	end
end

function KatiaDecorEditor:OnColorBuy()
	if #self.queued >= 1 then
		local dec = HousingLib.GetResidence():GetDecorById(self.queued[1].low, self.queued[1].high)
		if dec ~= nil then
			dec:Select()
			self:RefreshColorPreview(dec)
			Utils:Locate()
		end
		table.remove(self.queued, 1)
		self:RefreshQueue()
	else
		self.wndColor:FindChild("List"):DestroyChildren()
		self.wndColor:FindChild("SelectedModel"):SetDecorInfo(10)
	end
end

function KatiaDecorEditor:OnSkipColor()
	Utils:Place()
	self:OnColorBuy()
end

function KatiaDecorEditor:OnKatiaBuilderColor()
	self.wndColor:Invoke()
end

function KatiaDecorEditor:OnCancelColor()
	self.wndColor:Close()
end


Apollo.RegisterPackage(KatiaDecorEditor, MAJOR, MINOR, {})