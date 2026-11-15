--!strict
-- 경로: src/server/ExperienceSystem.server.luau
-- 매핑: ServerScriptService (Script)
--
-- 경험치 구슬(XP Gem) 드롭 + 자석 흡수 시스템.
--
-- 사용법 (다른 서버 스크립트에서):
--   local dropGem = game:GetService("ServerStorage"):WaitForChild("DropGem") :: BindableEvent
--   dropGem:Fire(position)                      -- 기본 XP(1)짜리 구슬
--   dropGem:Fire(position, 5)                   -- XP 5짜리 구슬
--   dropGem:Fire(position, 5, monsterModel)     -- 바닥 판정에서 monsterModel 은 무시
--
-- .server.luau 는 Script 라서 require 할 수 없으므로, DropGem 함수를 ServerStorage 의
-- BindableEvent("DropGem")로 공개한다. 획득한 경험치는 Player 의 "XP" Attribute 에 쌓인다.
--
-- 성능 원칙: 구슬은 Anchored, CanCollide/CanTouch/CanQuery 모두 꺼진 파츠이며
-- 물리·Touched 이벤트 없이 거리 계산(Magnitude)만으로 자석/습득을 판정한다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

---------------------------------------------------------------------------------------
-- 설정
---------------------------------------------------------------------------------------

local XP_ATTRIBUTE: string = "XP" -- Player 에 저장되는 경험치 Attribute 이름
local DEFAULT_GEM_XP: number = 1 -- xpValue 를 넘기지 않았을 때 구슬 1개의 경험치

local MAGNET_RADIUS: number = 15 -- 이 거리 안으로 들어오면 구슬이 플레이어에게 끌려간다
local COLLECT_RADIUS: number = 2 -- 이 거리 안이면 "몸에 닿은 것"으로 보고 습득한다
local SCAN_INTERVAL: number = 0.1 -- 바닥 구슬 ↔ 플레이어 거리 검사 주기(초)

local MAGNET_START_SPEED: number = 20 -- 끌려가기 시작할 때 속도 (기본 이동 속도 16보다 빨라야 한다)
local MAGNET_ACCELERATION: number = 120 -- 초당 가속
local MAGNET_MAX_SPEED: number = 90 -- 최고 속도

local MAX_GEMS: number = 600 -- 동시에 존재할 수 있는 구슬 수 상한 (넘으면 기존 구슬에 합친다)

local GEM_SIZE: Vector3 = Vector3.new(0.8, 0.8, 0.8)
local GEM_COLOR: Color3 = Color3.fromRGB(0, 255, 170)
local GEM_HOVER_HEIGHT: number = 1 -- 바닥에서 구슬 중심까지 높이
-- 큐브를 꼭짓점으로 세워 마름모처럼 보이게 하는 회전
local GEM_ORIENTATION: CFrame = CFrame.Angles(math.rad(-35.264), 0, math.rad(45))

local GROUND_RAY_UP: number = 2 -- 바닥 탐색 레이 시작 높이(드롭 위치 기준 위쪽)
local GROUND_RAY_LENGTH: number = 60 -- 바닥 탐색 레이 길이(아래쪽)

local GEM_FOLDER_NAME: string = "XPGems" -- Workspace 에 만들어지는 구슬 폴더
local DROP_EVENT_NAME: string = "DropGem" -- ServerStorage 에 만들어지는 BindableEvent
-- Workspace 에 이 이름의 폴더가 있으면 그 안의 인스턴스(몬스터)는 바닥으로 취급하지 않는다.
-- 폴더가 없어도 동작한다.
local MONSTER_FOLDER_NAME: string = "Monsters"

---------------------------------------------------------------------------------------
-- 타입 / 상태
---------------------------------------------------------------------------------------

type Gem = {
	part: Part,
	xp: number,
	cframe: CFrame, -- 현재 CFrame 캐시 (매번 프로퍼티를 읽지 않기 위함)
	position: Vector3, -- 현재 위치 캐시
	target: Player?, -- nil 이면 바닥에 놓인 상태, 값이 있으면 그 플레이어에게 끌려가는 상태
	speed: number,
}

type Collector = {
	root: BasePart,
	humanoid: Humanoid,
}

local idleGems: { Gem } = {} -- 바닥에 놓인 구슬
local flyingGems: { Gem } = {} -- 플레이어에게 끌려가는 구슬(Magnetized)
local recycleCursor: number = 0

local collectors: { [Player]: Collector } = {} -- 살아 있는 캐릭터를 가진 플레이어
local collectorPositions: { [Player]: Vector3 } = {} -- 이번 프레임의 플레이어 위치

-- BulkMoveTo 용 재사용 버퍼
local movedParts: { BasePart } = {}
local movedCFrames: { CFrame } = {}

local gemFolder = Instance.new("Folder")
gemFolder.Name = GEM_FOLDER_NAME
gemFolder.Parent = Workspace

local function createGemTemplate(): Part
	local gem = Instance.new("Part")
	gem.Name = "XPGem"
	gem.Shape = Enum.PartType.Block
	gem.Size = GEM_SIZE
	gem.Material = Enum.Material.Neon
	gem.Color = GEM_COLOR
	gem.Anchored = true
	gem.CanCollide = false
	gem.CanTouch = false
	gem.CanQuery = false
	gem.CastShadow = false
	gem.Massless = true
	gem.TopSurface = Enum.SurfaceType.Smooth
	gem.BottomSurface = Enum.SurfaceType.Smooth
	return gem
end

local gemTemplate: Part = createGemTemplate()

local groundRayParams = RaycastParams.new()
groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
groundRayParams.IgnoreWater = true

---------------------------------------------------------------------------------------
-- 유틸
---------------------------------------------------------------------------------------

-- 순서를 유지하지 않는 O(1) 삭제
local function swapRemove(list: { Gem }, index: number)
	local lastIndex = #list
	list[index] = list[lastIndex]
	list[lastIndex] = nil
end

-- position 아래의 바닥을 찾아, 구슬이 놓일 CFrame 을 돌려준다.
-- 플레이어 캐릭터, 몬스터 폴더, ignore 로 넘긴 인스턴스는 바닥으로 취급하지 않는다.
-- (구슬 자신은 CanQuery = false 라서 레이에 걸리지 않는다.)
local function getRestCFrame(position: Vector3, ignore: Instance?): CFrame
	local filter: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(filter, character)
		end
	end
	local monsterFolder = Workspace:FindFirstChild(MONSTER_FOLDER_NAME)
	if monsterFolder ~= nil then
		table.insert(filter, monsterFolder)
	end
	if ignore ~= nil then
		table.insert(filter, ignore)
	end
	groundRayParams.FilterDescendantsInstances = filter

	local origin = position + Vector3.new(0, GROUND_RAY_UP, 0)
	local direction = Vector3.new(0, -GROUND_RAY_LENGTH, 0)
	local result = Workspace:Raycast(origin, direction, groundRayParams)
	local groundY = if result ~= nil then result.Position.Y else position.Y

	return CFrame.new(position.X, groundY + GEM_HOVER_HEIGHT, position.Z) * GEM_ORIENTATION
end

local function awardXp(player: Player, amount: number)
	if player.Parent == nil then
		return -- 이미 나간 플레이어
	end
	local current = player:GetAttribute(XP_ATTRIBUTE)
	local total = (if typeof(current) == "number" then current else 0) + amount
	player:SetAttribute(XP_ATTRIBUTE, total)
end

---------------------------------------------------------------------------------------
-- 드롭
---------------------------------------------------------------------------------------

-- position 위치의 바닥에 경험치 구슬을 하나 떨어뜨린다.
--   xpValue : 구슬의 경험치 (생략 시 DEFAULT_GEM_XP)
--   ignore  : 바닥 판정에서 제외할 인스턴스 (보통 죽는 몬스터 모델)
local function DropGem(position: Vector3, xpValue: number?, ignore: Instance?)
	local xp = if xpValue ~= nil and xpValue > 0 then xpValue else DEFAULT_GEM_XP
	local restCFrame = getRestCFrame(position, ignore)

	-- 상한에 도달하면 새 파츠를 만들지 않고, 바닥에 있던 구슬 하나를 이 위치로 옮기며
	-- 경험치를 합친다. 구슬 수는 늘지 않고 경험치는 사라지지 않는다.
	local idleCount = #idleGems
	if idleCount > 0 and idleCount + #flyingGems >= MAX_GEMS then
		recycleCursor = recycleCursor % idleCount + 1
		local recycled = idleGems[recycleCursor]
		recycled.xp += xp
		recycled.cframe = restCFrame
		recycled.position = restCFrame.Position
		recycled.part.CFrame = restCFrame
		return
	end

	local part = gemTemplate:Clone() :: Part
	part.CFrame = restCFrame
	part.Parent = gemFolder

	local gem: Gem = {
		part = part,
		xp = xp,
		cframe = restCFrame,
		position = restCFrame.Position,
		target = nil,
		speed = 0,
	}
	table.insert(idleGems, gem)
end

---------------------------------------------------------------------------------------
-- 자석 / 습득
---------------------------------------------------------------------------------------

-- 살아 있는 플레이어들의 현재 위치를 한 번만 읽어 둔다.
local function refreshCollectorPositions()
	table.clear(collectorPositions)
	for player, collector in collectors do
		if collector.humanoid.Health > 0 and collector.root.Parent ~= nil then
			collectorPositions[player] = collector.root.Position
		end
	end
end

-- 바닥 구슬 중 자석 범위 안에 플레이어가 들어온 것을 Magnetized 상태로 전환한다.
local function scanIdleGems()
	if next(collectorPositions) == nil then
		return
	end

	for index = #idleGems, 1, -1 do
		local gem = idleGems[index]
		local gemPosition = gem.position
		local nearestPlayer: Player? = nil
		local nearestDistance = MAGNET_RADIUS

		for player, playerPosition in collectorPositions do
			local distance = (playerPosition - gemPosition).Magnitude
			if distance <= nearestDistance then
				nearestDistance = distance
				nearestPlayer = player
			end
		end

		if nearestPlayer ~= nil then
			gem.target = nearestPlayer
			gem.speed = MAGNET_START_SPEED
			swapRemove(idleGems, index)
			table.insert(flyingGems, gem)
		end
	end
end

-- Magnetized 구슬을 대상 플레이어 쪽으로 이동시키고, 닿으면 습득 처리한다.
local function updateFlyingGems(deltaTime: number)
	table.clear(movedParts)
	table.clear(movedCFrames)

	for index = #flyingGems, 1, -1 do
		local gem = flyingGems[index]
		local target = gem.target
		local targetPosition: Vector3? = if target ~= nil then collectorPositions[target] else nil

		if target ~= nil and targetPosition ~= nil then
			gem.speed = math.min(gem.speed + MAGNET_ACCELERATION * deltaTime, MAGNET_MAX_SPEED)
			local distance = (targetPosition - gem.position).Magnitude
			local step = gem.speed * deltaTime

			if distance - step <= COLLECT_RADIUS then
				-- 플레이어 몸에 닿음 → 구슬 제거 + 경험치 지급
				swapRemove(flyingGems, index)
				gem.part:Destroy()
				awardXp(target, gem.xp)
			else
				-- 플레이어의 "현재" 위치를 향해 이번 프레임에 갈 만큼만 Lerp 한다.
				local goal = CFrame.new(targetPosition) * GEM_ORIENTATION
				local nextCFrame = gem.cframe:Lerp(goal, step / distance)
				gem.cframe = nextCFrame
				gem.position = nextCFrame.Position
				table.insert(movedParts, gem.part)
				table.insert(movedCFrames, nextCFrame)
			end
		else
			-- 대상이 죽었거나 나감 → 그 자리의 바닥에 다시 내려놓는다.
			local restCFrame = getRestCFrame(gem.position, nil)
			gem.cframe = restCFrame
			gem.position = restCFrame.Position
			gem.target = nil
			gem.speed = 0
			swapRemove(flyingGems, index)
			table.insert(idleGems, gem)
			table.insert(movedParts, gem.part)
			table.insert(movedCFrames, restCFrame)
		end
	end

	-- 움직인 구슬을 한 번의 호출로 일괄 이동한다.
	if #movedParts > 0 then
		Workspace:BulkMoveTo(movedParts, movedCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local scanElapsed: number = 0

local function onHeartbeat(deltaTime: number)
	scanElapsed += deltaTime
	local scanDue = scanElapsed >= SCAN_INTERVAL and #idleGems > 0
	local hasFlying = #flyingGems > 0
	if not scanDue and not hasFlying then
		return
	end

	refreshCollectorPositions()

	if scanDue then
		scanElapsed = 0
		scanIdleGems()
	end

	if #flyingGems > 0 then
		updateFlyingGems(deltaTime)
	end
end

---------------------------------------------------------------------------------------
-- 플레이어 추적
---------------------------------------------------------------------------------------

local function onCharacterAdded(player: Player, character: Model)
	collectors[player] = nil

	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)

	-- 기다리는 동안 플레이어가 나갔거나 캐릭터가 바뀌었으면 등록하지 않는다.
	if player.Parent == nil or player.Character ~= character then
		return
	end

	if root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid:IsA("Humanoid") then
		local collector: Collector = { root = root, humanoid = humanoid }
		collectors[player] = collector

		humanoid.Died:Connect(function()
			if collectors[player] == collector then
				collectors[player] = nil
			end
		end)
	end
end

local function onPlayerAdded(player: Player)
	if player:GetAttribute(XP_ATTRIBUTE) == nil then
		player:SetAttribute(XP_ATTRIBUTE, 0)
	end

	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)

	player.CharacterRemoving:Connect(function(character: Model)
		local collector = collectors[player]
		if collector ~= nil and collector.root:IsDescendantOf(character) then
			collectors[player] = nil
		end
	end)

	local character = player.Character
	if character ~= nil then
		task.spawn(onCharacterAdded, player, character)
	end
end

local function onPlayerRemoving(player: Player)
	collectors[player] = nil
	collectorPositions[player] = nil
end

---------------------------------------------------------------------------------------
-- 시작
---------------------------------------------------------------------------------------

-- 다른 스크립트가 WaitForChild 로 바로 찾을 수 있도록 이벤트를 가장 먼저 공개한다.
local dropEvent = Instance.new("BindableEvent")
dropEvent.Name = DROP_EVENT_NAME
dropEvent.Parent = ServerStorage

dropEvent.Event:Connect(function(position: any, xpValue: any, ignore: any)
	if typeof(position) ~= "Vector3" then
		warn(`[ExperienceSystem] DropGem: position 은 Vector3 여야 합니다. (받은 값: {typeof(position)})`)
		return
	end
	local xp: number? = if typeof(xpValue) == "number" then xpValue else nil
	local ignoreInstance: Instance? = if typeof(ignore) == "Instance" then ignore else nil
	DropGem(position, xp, ignoreInstance)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

RunService.Heartbeat:Connect(onHeartbeat)
