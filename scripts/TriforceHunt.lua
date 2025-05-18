TriforceHunt = CustomItem:extend()

function TriforceHunt:init()
	self:createItem("Triforce Hunt") 
	self.code = "triforcehunt"
    self:setProperty("active", true)
	self.hunt = false
	self.ItemInstance.PotentialIcon = ImageReference:FromPackRelativePath(self.currentImage)
	self.currentOverlay = "null"
	self:updateIcon()
end

function TriforceHunt:canProvideCode(code)
    if code == self.code then
        return true
    else
        return false
    end
end

function TriforceHunt:providesCode(code)
    if code == self.code then
        return 1
    end
    return 0
end



function CustomItem:propertyChanged(key, value)
	self:SetTriforceHunt(true)
end

function TriforceHunt:SetTriforceHunt(on)
	if on then
		self.hunt = true
	else
		self.hunt = false
	end
	self:updateIcon()
end

function TriforceHunt:updateIcon()
	if self.hunt then
		self.currentImage = "images/z-triforce.png"
		self.currentOverlay = "null"
	else
		self.currentImage = "images/blank.png"
		self.currentOverlay = "null"
	end
	self.ItemInstance.Icon = ImageReference:FromPackRelativePath(self.currentImage, self.currentOverlay)
end
