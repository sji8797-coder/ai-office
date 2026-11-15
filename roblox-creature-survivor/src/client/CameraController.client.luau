--!strict
-- 경로: src/client/CameraController.client.luau
-- 매핑: StarterPlayer.StarterPlayerScripts (LocalScript)
--
-- 쿼터뷰 고정 카메라.
-- 매 프레임 플레이어의 HumanoidRootPart 위치를 따라가며, 플레이어 뒤쪽 위(CAMERA_OFFSET)에서
-- 고정된 각도로 내려다본다. CameraType 을 Scriptable 로 묶어 두므로 마우스 휠 줌이나
-- 우클릭 회전으로는 시점이 바뀌지 않는다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- 플레이어 기준 카메라 위치. Y +25(위), Z +20(뒤).
-- 이 오프셋에서 플레이어를 바라보면 X축 기울기는 -atan(25 / 20) = 약 -51.3도가 된다.
-- 각도를 바꾸고 싶으면 Y와 Z의 비율만 조절하면 된다. (예: 정확히 -50도 = Y 24.5, Z 20.6)
local CAMERA_OFFSET: Vector3 = Vector3.new(0, 25, 20)
local FIELD_OF_VIEW: number = 70

-- 회전값은 변하지 않으므로 한 번만 계산해 두고 매 프레임 재사용한다.
local CAMERA_ROTATION: CFrame = CFrame.lookAt(CAMERA_OFFSET, Vector3.zero).Rotation

local localPlayer: Player = Players.LocalPlayer
local trackedRoot: BasePart? = nil

-- 현재 캐릭터의 HumanoidRootPart 를 돌려준다. 리스폰으로 캐릭터가 바뀌면 다시 찾는다.
local function getRootPart(): BasePart?
	local character = localPlayer.Character
	if character == nil then
		trackedRoot = nil
		return nil
	end

	local cached = trackedRoot
	if cached ~= nil and cached.Parent == character then
		return cached
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		trackedRoot = root
		return root
	end

	trackedRoot = nil
	return nil
end

local function onRenderStepped(_deltaTime: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	-- 기본 카메라 스크립트나 리스폰 과정에서 값이 되돌아가도 다음 프레임에 다시 잠근다.
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if camera.FieldOfView ~= FIELD_OF_VIEW then
		camera.FieldOfView = FIELD_OF_VIEW
	end

	-- 캐릭터가 없는 동안(사망 후 리스폰 대기 등)에는 마지막 시점을 그대로 유지한다.
	local root = getRootPart()
	if root == nil then
		return
	end

	local rootPosition = root.Position
	camera.CFrame = CAMERA_ROTATION + (rootPosition + CAMERA_OFFSET)
	camera.Focus = CFrame.new(rootPosition)
end

RunService.RenderStepped:Connect(onRenderStepped)
