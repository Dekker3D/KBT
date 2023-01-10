local MAJOR, MINOR = "Module:KatiaDecorFinder-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local KatiaDecorFinder = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
KatiaDecorFinder.null = setmetatable ({}, {
  __toinn = function () return "null" end
})
local Utils = Apollo.GetPackage("Module:KatiaBuildUtils-1.0").tPackage
local DecorEditor = Apollo.GetPackage("Module:KatiaDecorEditor-1.0").tPackage

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

function KatiaDecorFinder:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("KatiaDecorFinder.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)

end

function KatiaDecorFinder:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndFinder = Apollo.LoadForm(self.xmlDoc, "FinderForm", nil, self)
		if self.wndFinder == nil then
			Apollo.AddAddonErrorText(self, "Could not load the decor finder window for some reason.")
			return
		end

	    self.wndFinder:Show(false, true)
		if self.bgOpacity ~= nil then
			self.wndFinder:SetBGOpacity(self.bgOpacity)
		end
	end
end

function KatiaDecorFinder:Open()
	self.wndFinder:Invoke() -- show the window
end

function KatiaDecorFinder:Close()
	self.wndFinder:Close() -- hide the window
end

function KatiaDecorFinder:SetBGOpacity(value)
	self.bgOpacity = value
	if self.wndFinder ~= nil then
		self.wndFinder:SetBGOpacity(value)
	end
end

function KatiaDecorFinder:Target(targetedId, targetedIdHigh)
	self.targetedId = targetedId
	self.targetedIdHigh = targetedIdHigh
	if targetedId == nil then
		self.wndFinder:FindChild("Link"):SetBGColor({a=1,r=1,b=1,g=1})
	else
		self.wndFinder:FindChild("Link"):SetBGColor({a=1,r=0,b=1,g=0})
	end
end

function KatiaDecorFinder:FindDecor(range, terms)
	local tPos = GameLib.GetPlayerUnit():GetPosition()
	local dPos = Utils:PlayerToDecorPos(tPos)

	self.wndFinder:Invoke()
	local wndList = self.wndFinder:FindChild("List")
	wndList:DestroyChildren()
	for i, dec in pairs(HousingLib.GetResidence():GetPlacedDecorList()) do
		local pack = Utils:DecorToPack(dec)
		if pack ~= nil then
			local distance = math.sqrt(math.pow(dPos.X - pack.X, 2) + math.pow(dPos.Y - pack.Y, 2) + math.pow(dPos.Z - pack.Z, 2))
			if (range == nil or range >= distance) and CheckMatchers(dec:GetName(), terms) then
				local wndListItem = Apollo.LoadForm(self.xmlDoc, "FinderItem", wndList, self)
				local data = {}
				data.low, data.high = dec:GetId()
				wndListItem:SetText(dec:GetName())
				wndListItem:SetData(data)
			end
		end
	end
	wndList:ArrangeChildrenVert()
end

function KatiaDecorFinder:OnLinkFound()
	local targeted = HousingLib.GetResidence():GetDecorById(self.targetedId, self.targetedIdHigh)
	if targeted == nil or targeted:GetName() == "" then
		targeted = HousingLib.GetResidence():GetSelectedDecor()
		if targeted == nil or targeted:GetName() == "" then
			self:FloatText("No decor selected or targetted")
			return
		end
	end
	local wndList = self.wndFinder:FindChild("List")
	for _, item in pairs(wndList:GetChildren()) do
		local dec = HousingLib.GetResidence():GetDecorById(item:GetData().low, item:GetData().high)
		if dec ~= nil then
			dec:Link(targeted)
		end
	end
	targeted:Place()
end

function KatiaDecorFinder:OnFinderSelect(wndHandler, wndControl)
	for _, win in pairs(wndHandler:GetParent():GetChildren()) do
		win:SetTextColor({a=1,r=1,b=1,g=1})
	end
	wndHandler:SetTextColor({a=1,r=0,b=1,g=0})
	local dec = HousingLib.GetResidence():GetDecorById(wndHandler:GetData().low, wndHandler:GetData().high)
	if dec ~= nil then
		dec:Select()
		Utils:Locate()
		DecorEditor:Refresh()
		DecorEditor:RefreshColorPreview(dec)
	end
end

function KatiaDecorFinder:OnFind()
	local terms = {}
	string.gsub(self.wndFinder:FindChild("Terms"):GetText(),
				"([^ ]+)", function(c) table.insert(terms, c) end)
	local range = tonumber(self.wndFinder:FindChild("Range"):GetText())

	self:FindDecor(range, terms)
end

-- /kfind
function KatiaDecorFinder:Find(strArg)
	if strArg == "" then
		self:OnFind()
		return
	end
	local terms = {}
	string.gsub(strArg, "([^ ]+)", function(c) table.insert(terms, c) end)
	local range = tonumber(terms[1])
	if range ~= nil then
		table.remove(terms, 1)
	end

	self:FindDecor(range, terms)
end


Apollo.RegisterPackage(KatiaDecorFinder, MAJOR, MINOR, {})