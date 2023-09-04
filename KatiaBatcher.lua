local MAJOR, MINOR = "Module:KatiaBatcher-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local KatiaBatcher = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
KatiaBatcher.null = setmetatable ({}, {
  __toinn = function () return "null" end
})

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

function KatiaBatcher:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("KatiaBatcher.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	Apollo.RegisterEventHandler("HousingMyResidenceDecorChanged", "OnTodoDecor", self)
	Apollo.RegisterEventHandler("HousingRandomResidenceListRecieved", "OnTodoScan", self)
	self.watchDecor = false
	self.watchScan = false
end

function KatiaBatcher:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
		self.wndProg = Apollo.LoadForm(self.xmlDoc, "ProgressForm", nil, self)
		self.barProg = self.wndProg:FindChild("ProgressBar")
		if self.wndProg == nil then
			Apollo.AddAddonErrorText(self, "Could not load the progress bar for some reason.")
			return
		end
		self.wndProg:Show(false, true)
	end
end

-- todoFunc is executed on each item, finishFunc is executed when an item is completed, finalFunc is executed when the entire operation is completed
function KatiaBatcher:Prepare(todoFunc, finishFunc, finalFunc)
	if self.todo ~= nil then
		self:FloatText("Wait for current action to finish")
		return nil
	end
	
	self.todoFunc = todoFunc
	self.finishFunc = finishFunc
	self.finalFunc = finalFunc
	self.todo = {}
	return self.todo
end

function KatiaBatcher:StartTimed(delay)
	self.wndProg:Invoke()
	self.barProg:SetMax(#self.todo)
	self.todoTimer = ApolloTimer.Create(delay, true, "OnTodo", self)
end

function KatiaBatcher:StartDecorDriven()
	self.wndProg:Invoke()
	self.barProg:SetMax(#self.todo)
	self.watchDecor = true
	self.seen = {}
	self:ProcessTodo()
end

function KatiaBatcher:StartScanDriven()
	self.wndProg:Invoke()
	self.barProg:SetMax(#self.todo)
	self.watchScan = true
	HousingLib.RequestRandomResidenceList()
end

function KatiaBatcher:OnTodoDecor(decor)
	if self.watchDecor then
		if decor ~= nil then
			local low, high = decor:GetId()
			if low ~= 0 or high ~= 0 then
				if self.seen[low] ~= nil and self.seen[low][high] then
					return
				else
					if self.seen[low] == nil then
						self.seen[low] = {}
					end
					self.seen[low][high] = true
				end
			end
		end
		self:OnTodo(decor)
	end
end

function KatiaBatcher:OnTodoScan()
	if self.watchScan then
		self:OnTodo()
	end
end

function KatiaBatcher:OnTodo(item)
	if self.finishFunc ~= nil then
		self:finishFunc(item)
	end
	if #self.todo == 0 then
		if self.finalFunc ~= nil then
			self:finalFunc(item)
		end
		if self.todoTimer ~= nil then
			self.todoTimer:Stop()
			self.todoTimer = nil
		end
		self.watchDecor = false
		self.watchScan = false
		self.todo = nil
		self.wndProg:Close()
		self.todoFunc = nil
		self.finishFunc = nil
		self.finalFunc = nil
	else
		self.barProg:SetProgress(self.barProg:GetMax() - #self.todo)
		self:ProcessTodo()
	end
end

function KatiaBatcher:ProcessTodo()
	if #self.todo > 0 then
		self:todoFunc(table.remove(self.todo, 1))
	else
		self.todo = nil
		self.wndProg:Close()
		self.todoFunc = nil
		self.finishFunc = nil
		self.finalFunc = nil
	end
end

function KatiaBatcher:OnCancelOperation()
	self.todo = {}
end

Apollo.RegisterPackage(KatiaBatcher, MAJOR, MINOR, {})