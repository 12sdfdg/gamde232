--!nonstrict
-- Маленька бібліотека для побудови UI з коду + спільна тема.

local TweenService = game:GetService("TweenService")

local UI = {}

UI.Font = Enum.Font.FredokaOne

UI.Colors = {
	Panel = Color3.fromRGB(32, 34, 52),
	PanelLight = Color3.fromRGB(48, 52, 78),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(180, 185, 210),
	Speed = Color3.fromRGB(80, 200, 255),
	Wins = Color3.fromRGB(255, 205, 60),
	Rebirth = Color3.fromRGB(200, 110, 255),
	Green = Color3.fromRGB(70, 210, 100),
	Red = Color3.fromRGB(255, 80, 90),
	Orange = Color3.fromRGB(255, 150, 50),
	Robux = Color3.fromRGB(40, 190, 90),
}

function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.corner(radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UI.stroke(color: Color3?, thickness: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.textStroke(thickness: number?): UIStroke
	return UI.new("UIStroke", { Thickness = thickness or 2, Color = Color3.new(0, 0, 0) })
end

function UI.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return UI.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UI.gradient(top: Color3, bottom: Color3): UIGradient
	return UI.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

function UI.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

function UI.label(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		RichText = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	local label = UI.new("TextLabel", defaults)
	UI.textStroke(1.5).Parent = label
	return label
end

-- Кнопка з «пружинною» анімацією натискання.
function UI.button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local defaults: { [string]: any } = {
		AutoButtonColor = false,
		Font = UI.Font,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		RichText = true,
		BackgroundColor3 = UI.Colors.Green,
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = UI.new("TextButton", defaults) :: TextButton
	UI.corner(12).Parent = button
	UI.stroke(Color3.new(0, 0, 0), 2.5).Parent = button
	UI.textStroke(1.5).Parent = button
	UI.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
		Rotation = 90,
	}).Parent = button
	local scale = UI.new("UIScale", { Parent = button }) :: UIScale
	button.MouseEnter:Connect(function()
		UI.tween(scale, 0.12, { Scale = 1.06 })
	end)
	button.MouseLeave:Connect(function()
		UI.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UI.tween(scale, 0.06, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		UI.tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- Червоний кружечок-лічильник у кутку кнопки.
function UI.badge(parent: GuiObject): TextLabel
	local badge = UI.label({
		Name = "Badge",
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, -14, 0, -10),
		BackgroundTransparency = 0,
		BackgroundColor3 = UI.Colors.Red,
		Text = "!",
		ZIndex = 5,
		Visible = false,
		Parent = parent,
	})
	UI.corner(12).Parent = badge
	return badge
end

return UI
