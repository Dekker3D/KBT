local MAJOR, MINOR = "Module:KatiaPlotFinder-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local KatiaPlotFinder = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
KatiaPlotFinder.null = setmetatable ({}, {
  __toinn = function () return "null" end
})
local Batcher = Apollo.GetPackage("Module:KatiaBatcher-1.0").tPackage
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

-- Check if all strings in matchers are in check
local function CheckMatchers(check, matchers)
	for _,i in pairs(matchers) do
		if string.find(string.lower(check), string.lower(i)) == nil then
			return false
		end
	end
	return true
end

function KatiaPlotFinder:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("KatiaPlotFinder.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function KatiaPlotFinder:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndFindPlot = Apollo.LoadForm(self.xmlDoc, "PlotFinderForm", nil, self)
		if self.wndFindPlot == nil then
			Apollo.AddAddonErrorText(self, "Could not load the plot finder window for some reason.")
			return
		end
	    self.wndFindPlot:Show(false, true)
		if self.bgOpacity ~= nil then
			self.wndFindPlot:SetBGOpacity(self.bgOpacity)
		end
	end
end

function KatiaPlotFinder:Open()
	self.wndFindPlot:Invoke() -- show the window
end

function KatiaPlotFinder:Close()
	self.wndFindPlot:Close() -- hide the window
end

function KatiaPlotFinder:SetBGOpacity(value)
	self.bgOpacity = value
	if self.wndFindPlot ~= nil then
		self.wndFindPlot:SetBGOpacity(value)
	end
	if self.wndFindPlot ~= nil then
		self.wndFindPlot:SetBGOpacity(value)
	end
end

function KatiaPlotFinder:OnFindPlot()
	local terms = {}
	string.gsub(self.wndFindPlot:FindChild("Terms"):GetText(),
				"([^ ]+)", function(c) table.insert(terms, c) end)
	local tries = tonumber(self.wndFindPlot:FindChild("Tries"):GetText())

	self:ScanPlots(tries, terms)
end

function KatiaPlotFinder:OnFindPlotSelect(wndHandler, wndControl)
	HousingLib.RequestVisitPlayer(wndHandler:GetData())
end

function KatiaPlotFinder:ScanPlots(tries, terms)
	self.plotResults = {}
	self.plotTerms = terms
	if tries == nil then
		tries = 100
	end
	local todo = Batcher:Prepare(
		function ()
			for _, plot in pairs(HousingLib.GetRandomResidenceList()) do
				if CheckMatchers(plot.strCharacterName, self.plotTerms) or
					CheckMatchers(plot.strResidenceName, self.plotTerms) then
					self.plotResults[plot.strCharacterName] = plot.strResidenceName
				end
			end
	
			self.wndFindPlot:Invoke()
			local wndList = self.wndFindPlot:FindChild("List")
			wndList:DestroyChildren()
			for player, home in pairs(self.plotResults) do
				local wndListItem = Apollo.LoadForm(self.xmlDoc, "FindPlotItem", wndList, self)
				wndListItem:SetText(player .. " - " .. home)
				wndListItem:SetData(player)
			end
			wndList:ArrangeChildrenVert()
			HousingLib.RequestRandomResidenceList()
		end,
		nil,
		nil
	)
	if todo == nil then return end
	for i=1,tries do
		table.insert(todo, i)
	end
	Batcher:StartScanDriven()
end

Apollo.RegisterPackage(KatiaPlotFinder, MAJOR, MINOR, {})