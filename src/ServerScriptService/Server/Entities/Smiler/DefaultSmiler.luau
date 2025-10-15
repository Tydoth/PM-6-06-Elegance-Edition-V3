--!strict

-- Default Smiler class

-- Variables
local ServerScriptService = game:GetService("ServerScriptService")
local Server      = ServerScriptService:FindFirstChild("Server")
local Services    = Server:FindFirstChild("Services")
local Modules     = Server:FindFirstChild("Modules")
local Composition = Modules:FindFirstChild("Composition")
local Utility     = Modules:FindFirstChild("Utility")

-- Packets
local Finder      = require(Composition:FindFirstChild("Finder"))
local Waypoint    = require(Composition:FindFirstChild("Waypoint"))
local PlayerUtils = require(Utility:FindFirstChild("PlayerUtils"))
local Sounds      = require(Composition:FindFirstChild("Sounds"))
local Damage      = require(Utility:FindFirstChild("Damage"))
local TickRate    = require(Services:FindFirstChild("TickRate"))

-- Constants
local DEFAULT_SIGHT                     : number  = 35
local DEFAULT_LOSE_PLAYER_DURATION      : number  = 3
local DEFAULT_WAYPOINT_MOVE_TO_DURATION : number  = 1
local DEFAULT_DAMAGE                    : number  = 20
local DEFAULT_DAMAGE_IFRAMES            : number  = 2
local DEFAULT_ATTEMPT_FIND_AFTER_LOSE   : boolean = true

-- Module
local Smiler = {}
Smiler.__index = Smiler

export type SmilerParams = {
  Range                  : number?,
  LosePlayerDuration     : number?,
  AttemptFindAfterLose   : boolean?,
  WaypointMoveToDuration : number?,
  Damage                 : number?,
  DamageIFrames          : number?,
  PathfindingParams      : Waypoint.PathfindingParameters?
}
export type Smiler = typeof(
  setmetatable({} ::  {
    Root                   : Model,
    Humanoid               : Humanoid,
    Sight                  : number,
    LosePlayerDuration     : number,
    AttemptFindAfterLose   : boolean,
    WaypointMoveToDuration : number,
    Sounds                 : Sounds.Sounds,
    Damage                 : number,
    DamageIFrames          : number,
    Finder                 : Finder.Finder,
    Waypoint               : Waypoint.Waypoint
  }, Smiler)
)

function Smiler.new(target : Model, params : SmilerParams?): (Smiler)
  assert(target)
  return setmetatable({
    Root                   = target,
    Humanoid               = (target:FindFirstChildOfClass("Humanoid") :: Humanoid),
    Sight                  = (params and params.Range or DEFAULT_SIGHT),
    LosePlayerDuration     = (params and params.LosePlayerDuration or DEFAULT_LOSE_PLAYER_DURATION),
    AttemptFindAfterLose   = (params and params.AttemptFindAfterLose or DEFAULT_ATTEMPT_FIND_AFTER_LOSE) :: boolean, -- what the hell typechecking
    WaypointMoveToDuration = (params and params.WaypointMoveToDuration or DEFAULT_WAYPOINT_MOVE_TO_DURATION),
    Damage                 = (params and params.Damage or DEFAULT_DAMAGE),
    DamageIFrames          = (params and params.DamageIFrames or DEFAULT_DAMAGE_IFRAMES),
    Sounds                 = Sounds.new(
      (target:FindFirstChild("Sounds")           :: Folder),
      (target:FindFirstChild("HumanoidRootPart") :: BasePart)
    ),
    Finder                 = Finder(target),
    Waypoint               = Waypoint(target,
      (((target.Parent :: Folder)
        :FindFirstChild("Waypoints") :: Folder)
        :GetChildren() :: {PVInstance})
    )
  }, Smiler)
end

-- Attacking behavior i guess
function Smiler.Attack(self : Smiler, target: PVInstance): ()
  if (not self.Finder:IsTargetInRange(target, 5)) then
    return
  end
  local humanoid = (target:FindFirstChild("Humanoid") :: Humanoid)
  if (not humanoid) then
    return
  end
  local attacked : boolean, died : boolean = Damage:Damage(humanoid, self.Damage)
  if (not attacked) then
    return
  end
-- stupid if statements in my way
  if (died) then
    self.Sounds:PlaySound("KilledTarget")
  else
    self.Sounds:PlaySound("Hit")
  end
end

-- when the smiler is mad
function Smiler.Aggro(self : Smiler, closest: PVInstance): ()
  self.Sounds:PlaySound("Yell")
  self.Sounds:PlaySound("TargetFound")
  while (self.Finder:CanSeeTarget(closest, self.Sight)) do
    local pivot : CFrame  = closest:GetPivot()
    local pos   : Vector3 = pivot.Position
    self.Humanoid:MoveTo(pos)
    self:Attack(closest)
    TickRate:WaitInterval(0.25) -- hardcoded becauslazy
  end

  if self.AttemptFindAfterLose == true then
    local path : {PathWaypoint} = self.Waypoint:GetPath(closest)
    for i = 1, #path do
      self:Check(closest)
      self.Humanoid:MoveTo(path[i].Position)
      self.Humanoid.MoveToFinished:Wait()
    end
  else
    self.Sounds:StopSound("Yell")
    TickRate:WaitInterval(self.LosePlayerDuration)
  end

  self.Sounds:StopSound("Yell")
  self:Patrol()
end

-- basically an if statement disguised as a function
function Smiler.Check(self : Smiler, closest : PVInstance): ()
  local isInRange : boolean = self.Finder:IsTargetInRange(closest, self.Sight)
  local canSee    : boolean = self.Finder:CanSeeTarget(closest, self.Sight)
  if (isInRange and canSee) then
    self:Aggro(closest)
  end
end

-- schmoving
function Smiler.MoveToPoint(self : Smiler): ()
  local point       : PVInstance     = self.Waypoint:GetWaypoint()
  local path        : {PathWaypoint} = self.Waypoint:GetPath(point)
  local playerChars : {PVInstance}   = PlayerUtils.GetPlayerCharacters()
  for _, point in path do
    if (#playerChars ~= 0) then
      self:Check(self.Finder:GetClosestTargetInArray(playerChars))
    end
    self.Humanoid:MoveTo(point.Position)
    self.Humanoid.MoveToFinished:Wait()
  end
end

-- Entity loop
function Smiler.Patrol(self : Smiler): ()
  while (self.Root ~= nil) do
    self:MoveToPoint()
    self.Sounds:PlaySound("WaypointWent")
    TickRate:WaitInterval(self.WaypointMoveToDuration)
  end
end

return Smiler
