local middleDigitImage = {
	"images/0.png",
	"images/1.png",
	"images/2.png",
	"images/3.png",
	"images/4.png",
	"images/5.png",
	"images/6.png",
	"images/7.png",
	"images/8.png",
	"images/9.png",
}

local leftDigitImage = {
	"overlay|images/1Left.png",
	"overlay|images/2Left.png",
	"overlay|images/3Left.png",
	"overlay|images/4Left.png",
	"overlay|images/5Left.png",
	"overlay|images/6Left.png",
	"overlay|images/7Left.png",
	"overlay|images/8Left.png",
	"overlay|images/9Left.png",
}

local rightDigitImage = {
	"images/0Right.png",
	"images/1Right.png",
	"images/2Right.png",
	"images/3Right.png",
	"images/4Right.png",
	"images/5Right.png",
	"images/6Right.png",
	"images/7Right.png",
	"images/8Right.png",
	"images/9Right.png",
}

TriforceCount = CustomItem:extend()

function TriforceCount:init()
	self:createItem("Triforce Counter") 
	self.code = "triforcecounter"
    self:setProperty("active", true)
	self.currentImage = middleDigitImage[1]
	self.count = 0
	self.ItemInstance.PotentialIcon = ImageReference:FromPackRelativePath(self.currentImage)
	self.currentOverlay = "null"
	self:updateIcon()
end

function TriforceCount:canProvideCode(code)
    if code == self.code then
        return true
    else
        return false
    end
end

function TriforceCount:providesCode(code)
    if code == self.code then
        return 1
    end
    return 0
end


--[[
function CustomItem:propertyChanged(triforce, value)
	self:SetTriforce(true)
end
]]

function TriforceCount:onLeftClick()
	if self.count > 99 then
		self.count = 0
	else
		self.count = self.count + 1
	end
	self:updateIcon()
end

function TriforceCount:onRightClick()
	if self.count < 1 then
		self.count = 100
	else
		self.count = self.count - 1
	end
	self:updateIcon()
end

function TriforceCount:updateIcon()
	if self.count < 10 then
		self.currentImage = middleDigitImage[self.count+1]
		self.currentOverlay = "null"
	elseif self.count > 99 then
		self.currentImage = "images/100.png"
		self.currentOverlay = "null"
	else
		self.currentImage = rightDigitImage[(self.count%10)+1]
		self.currentOverlay = leftDigitImage[((self.count - (self.count%10))/10)]
	end
	self.ItemInstance.Icon = ImageReference:FromPackRelativePath(self.currentImage, self.currentOverlay)
end

function TriforceCount:save()
	local saveData = {
		["count"] = self.count
	}
	return saveData
end

function TriforceCount:load(data)
	if data ~= nil then
		self.count = data["count"]
		self:updateIcon()
	end
	return true
end