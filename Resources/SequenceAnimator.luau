--!optimize 2
--!ceat_ceat

-- all files with my name near the top are written by me and me only
-- users and editers, please leave my name and the url where they are,
-- esp if you release your own version
-- (i would advise you also put your name near the top)

--[[
	ceat's KeyframeSequence Animator - https://roblox.com/library/15329902944
	
	Custom Animator class that tries to perfectly emulate the roblox animator
	(+ some additional features). Solves issues that other animators have such
	as lack of fading when a new animation plays, animation conflicts, and lack
	of weighting by containing all animations on a particular
	Humanoid/AnimationController into one Animator object instead of many
	
	Animators are self-contained. An Animator will not respect the state of
	another, which will cause animating conflicts. Please only use create one
	Animator per each given Humanoid/AnimationController
	
	It is recommended to use this module on the client, as changes to the
	Transform property on the server are overwritten by the client's animating
	processes and large amounts of replication packets. It has been made possible
	for a server-side usage of the module to replicate animations fully to the
	client, which is outlined below
	
	Additional stuff added on top of emulating Roblox animation APIs  ------------
			
		RBXScriptSignal Stepped ({ [string]: CFrame }):
			Event that fires every Stepped that passes the new transforms for
			each Motor6D
			
	Usage example ----------------------------------------------------------------
	
		local Animator = require(module)
		
		local animator = Animator.new(model)
		
		local track = animator:LoadAnimation(keyframeSequence)
		track:Play()
		
		animator.Stepped:Connect(function(cframes)
			for jointName, transform in cframes do
				print("transform of", jointName, "is now", transform)
			end
		end)
		
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local typeof = typeof
local ipairs = ipairs
local error = error
local tableConcat = table.concat
local round = math.round
local clock = os.clock
local min = math.min
local tclear = table.clear
local cframeIdentity = CFrame.identity

local getValue = TweenService.GetValue
local easingDirections = Enum.EasingDirection:GetEnumItems()

local Animators = setmetatable({}, {__mode = "k"})
local AnimationTracks = setmetatable({}, {__mode = "k"})

local Animator = {}
Animator.__index = Animator

-- ceat_ceat

--[[
	AnimationTrack - the main thing
]]



--[[

           +++                                                                                      
       ++++++++   ===                                                                               
    ++++++++++   ====                                                  ====                         
     ++++++                                                            ====                         
       +++++     ====     ====== ====+  ==== ======+      ========     ====        ====             
        +++++    ====    ============+  =============    ===========   ====        ====             
         ++++    ====   ====     ====+  =====    ====           ====   ====        ====             
         ++++    ====   ====     ====+  =====    ====     ==========   ====    =============        
         ++++    ====   ====     ====+  =====    ====   ======  ====   ====    ++++====++++=        
       ++++++    ====   =====   =====+  =====    ====  ====     ====   ====        ====    +++++++++
   ++++++++++    ====    ============+  =====    ====   ============   ====   ++++ ==== ++++++++++++
  +++++++        ====            ====+  ====     ====   + ====  ====   ==== ++++++++  +++++++*      
 +++++                  ====+    ==== +++++++++++++++++++++++++++++++++++++++++++++++++++++         
 ++++        +++++++++++ =========== +++++++++++++++++++++++++++++++++++++++      ++++++            
++++++++*++++++++++++++++++                                                         +               
 +++++++++++++++++++++++++                                                                          
      *++++                                                                                         

v2.6.0

An insanely fast, memory efficient, fully typed, featureful,
lightweight, open-source script signal module for Roblox.


GitHub:
https://github.com/AlexanderLindholt/SignalPlus

Devforum:
https://devforum.roblox.com/t/3552231


--------------------------------------------------------------------------------
MIT License

Copyright (c) 2025 AlexanderLindholt

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--------------------------------------------------------------------------------

]]--

-- Types.
export type Connection = {
	Disconnect: typeof(
		-- Disconnects the connection.
		-- To reconnect, make a new connection.
		function(connection: Connection) end
	),
	Connected: boolean
}
export type Signal<Parameters...> = {
	Connect: typeof(
		-- Connects the given function.
		function(signal: Signal<Parameters...>, callback: (Parameters...) -> ()): Connection end
	),
	Once: typeof(
		-- Connects the given function, but disconnects after first fire.
		function(signal: Signal<Parameters...>, callback: (Parameters...) -> ()): Connection end
	),
	Wait: typeof(
		-- Yields the current thread until the next fire.
		function(signal: Signal<Parameters...>): Parameters... end
	),

	Fire: typeof(
		-- Fires all callbacks and resumes all waiting threads.
		function(signal: Signal<Parameters...>, ...: Parameters...) end
	),

	DisconnectAll: typeof(
		-- Disconnects all connections.
		function(signal: Signal<Parameters...>) end
	),
	Destroy: typeof(
		-- Disconnects all connections, and makes the signal unusable.
		function(signal: Signal<Parameters...>) end
	),
}
type CreateSignal = typeof(
	-- Creates a new signal.
	function<Parameters...>(): Signal<Parameters...> end
)

-- No operation function.
local function noop()

end

-- Setup thread recycling.
local threads = {}
local function reusableThreadCall(callback, ...)
	callback(...)
	table.insert(threads, coroutine.running())
end
local function reusableThread(callback, ...)
	callback(...)
	table.insert(threads, coroutine.running())
	while true do
		reusableThreadCall(coroutine.yield())
	end
end

-- Connection class.
local connectionClass = table.freeze({__index = table.freeze({
	Disconnect = @native function(connection)
		-- Ensure it is already connected.
		if not connection.Connected then return end

		-- Remove from linked list.
		local previous = connection[2]
		local next = connection[3]
		if previous then
			previous[3] = next
		else
			connection[1][1] = next
		end
		if next then
			next[2] = previous
		end
		-- Set connected property.
		connection.Connected = false
		-- Clear values.
		connection[1] = nil
		connection[2] = nil
		connection[3] = nil
		connection[4] = nil
	end
})})

-- Signal class.
local signalClass = table.freeze({__index = table.freeze({
	Connect = @native function(signal, callback)
		-- Setup connection.
		local connection = setmetatable({
			[1] = signal,
			[2] = nil, -- Previous.
			[3] = signal[1], -- Next.
			[4] = callback,

			Connected = true
		}, connectionClass)
		signal[1] = connection

		-- Return connection.
		return connection
	end,
	Once = @native function(signal, callback)
		-- Setup connection.
		local connection = nil
		connection = setmetatable({
			[1] = signal,
			[2] = nil, -- Previous.
			[3] = signal[1], -- Next.
			[4] = @native function(...) -- Callback.
				-- Disconnect.
				local previous = connection[2]
				local next = connection[3]
				if previous then
					previous[3] = next
				else
					signal[1] = next
				end
				if next then
					next[2] = previous
				end
				connection[4] = nil
				connection.Connected = false

				-- Fire callback.
				callback(...)
			end,

			Connected = true
		}, connectionClass)
		signal[1] = connection

		-- Return connection.
		return connection
	end,
	Wait = @native function(signal)
		-- Save the thread (this) to resume later.
		local thread = coroutine.running()

		-- Setup connection.
		local connection = nil
		connection = {
			[1] = signal,
			[2] = nil, -- Previous.
			[3] = signal[1], -- Next.
			[4] = @native function(...) -- Callback.
				-- Disconnect.
				local previous = connection[2]
				local next = connection[3]
				if previous then
					previous[3] = next
				else
					signal[1] = next
				end
				if next then
					next[2] = previous
				end
				connection[4] = nil

				-- Resume the thread.
				task.spawn(thread, ...)
			end,
		}
		signal[1] = connection

		-- Yield until the next fire, and return the arguments on resume.
		return coroutine.yield()
	end,

	Fire = @native function(signal, ...)
		-- Fire all callbacks.
		local node = signal[1]
		while node do
			-- Find or create a thread, and run the callback in it.
			local length = #threads
			if length == 0 then
				task.spawn(reusableThread, node[4], ...)
			else
				local thread = threads[length]
				threads[length] = nil -- Remove from free threads list.
				task.spawn(thread, node[4], ...)
			end

			-- Go to the next connection.
			node = node[3]
		end
	end,

	DisconnectAll = @native function(signal)
		local node = signal[1]
		while node do
			local next = node[3]

			node[1] = nil
			node[2] = nil
			node[3] = nil
			node[4] = nil
			if node.Connected then -- Since 'Wait' connections don't have the 'Connected' property.
				node.Connected = false
			end

			node = next
		end
		signal[1] = nil
	end,
	Destroy = @native function(signal)
		-- Disconnect all.
		local node = signal[1]
		while node do
			local next = node[3]

			node[1] = nil
			node[2] = nil
			node[3] = nil
			node[4] = nil
			if node.Connected then -- Since 'Wait' connections don't have the 'Connected' property.
				node.Connected = false
			end

			node = next
		end
		signal[1] = nil

		-- Link all methods to noop (no operation) function.
		signal.Connect = noop
		signal.Once = noop
		signal.Wait = noop
		signal.Fire = noop
		signal.DisconnectAll = noop
		signal.Destroyed = noop
	end
})})

local Signal = @native function()
	return setmetatable({}, signalClass)
end :: CreateSignal

-- ceat_ceat

--[[
	easing - create a lookup table for TweenService GetValue calls in advance
	to mimize __index calls on instances + reintroduction of the Cubic reversed
	EasingDirections bug
]]

local easingFuncs = {}
-- pose easing style doesnt have all the regular easing styles for some reason whos fault is this
for _, poseEasingStyle in Enum.PoseEasingStyle:GetEnumItems() do
	local directions = {}
	if poseEasingStyle == Enum.PoseEasingStyle.Constant then
		for _, direction in easingDirections do
			directions[direction.Value] = function(a)
				return (a >= 1) and 1 or 0
			end
		end
		easingFuncs[poseEasingStyle.Value] = directions
		continue
	end
	if poseEasingStyle == Enum.PoseEasingStyle.CubicV2 then
		continue
	end
	local success, easingStyle = pcall(function()
		return Enum.EasingStyle[poseEasingStyle.Name]
	end)
	if not success then
		warn(`unable to process {poseEasingStyle.Name} easing style, some animations may cause the animator to error`)
		continue
	end
	for _, direction in easingDirections do
		-- EasingDirection maps directly to PoseEasingDirection
		directions[direction.Value] = function(a)
			return getValue(TweenService, a, easingStyle, direction)
		end
	end
	easingFuncs[poseEasingStyle.Value] = directions
end

easingFuncs[Enum.PoseEasingStyle.Constant.Value] = {
	[0] = round,
	[1] = round,
	[2] = round,
}

local cubic = easingFuncs[Enum.PoseEasingStyle.Cubic.Value]
easingFuncs[Enum.PoseEasingStyle.CubicV2.Value] = table.clone(cubic) -- usual cubic is cubicv2
cubic[0], cubic[1] = cubic[1], cubic[0] -- add back the incorrectly reversed easing directions that cubic has
-- (cubicv2 was made to fix this)

@native local function getLerpAlpha(a, poseEasingStyleValue, poseEasingDirectionValue)
	return easingFuncs[poseEasingStyleValue][poseEasingDirectionValue](a)
end

-- ceat_ceat

--[[
	assetType - type checkers
]]

local assertType = @native function(methodName, value, types, argNum)
	local t = typeof(value)
	for _, expectedType in types do
		if t == expectedType then
			return
		end
	end
	error(`invalid argument #{argNum} to '{methodName}' ({tableConcat(types, " or ")} expected, got {t})`)
end

local assertClass = @native function(methodName, instance, classes, argNum)
	assertType(methodName, instance, {"Instance"}, argNum)
	if type(classes) == "string" then
		classes = {classes}
	end
	local class = instance.ClassName
	for _, className in classes do
		if class == className then
			return
		end
	end
	error(`invalid argument #{argNum} to '{methodName}' ({table.concat(classes, ", or ")} expected, got {class})`)
end

local assertType = assertType
local assertClass = assertClass

local AnimationTrack = {}
AnimationTrack.__index = AnimationTrack

@native function AnimationTrack:AdjustSpeed(speed)
	self.Speed = speed
end

@native function AnimationTrack:AdjustWeight(weight, fadeTime)
	self.Weight = weight
	if self._setWeight then
		self._setWeight(weight, fadeTime)
	end
end

@native function AnimationTrack:GetMarkerReachedSignal(name)
	local event = self._markerReachedSignals[name]
	if not event then
		event = Signal("MarkerReached")
		self._markerReachedSignals[name] = event
	end
	return event
end

@native function AnimationTrack:GetTimeOfKeyframe(keyframeName)
	return self._keyframeTimes[keyframeName] or error("Could not find a keyframe by that name!")
end

-- localize stuff for better reach
local Lerp = cframeIdentity.Lerp or @native function(a,b,t)
	return a:Lerp(b,t)
end

@native function AnimationTrack:Play(fadeTime, weight, speed)
	fadeTime = fadeTime or 0.1
	weight = weight or self.Weight
	speed = speed or 1
	self.Speed = speed
	self.Weight = weight

	local keyframes = self._keyframes
	local keyframeTimes = self._keyframeTimes
	local keyframeNames = self._keyframeNamesOrdered -- sorted array
	local markerTimes = self._markerTimes
	local markerNames = self._markerNamesOrdered -- sorted array
	local markerReachedSignals = self._markerReachedSignals
	local transforms = table.clone(self._parent._transforms)
	local jointNames = self._jointNames

	local hasNamedKeyframes = #keyframeNames > 0
	local hasNamedMarkers = #markerNames > 0
	local nextPassKeyframeIdx = 1
	local nextPassMarkerIdx = 1

	local didLoopEvent = self.DidLoop
	local keyframeReachedEvent = self.KeyframeReached

	self._transforms = transforms -- get joints at current state to ease in

	local startTime = clock()
	local length = self.Length
	local timePosition = 0

	local poseIndexes = {}
	local nextPoseIndexes = {}
	local lastPoses = {}
	local nextPoses = {}
	local jointNames = self._jointNames

	-- for fading between weights
	local weightInitial = 0
	local weightFadeStart = startTime

	local function reset()
		for _, jointName in jointNames do
			lastPoses[jointName] = keyframes[jointName][1]
			nextPoses[jointName] = keyframes[jointName][2]
			poseIndexes[jointName] = 1
			nextPoseIndexes[jointName] = 2
		end
	end

	local function getCurrentTotalWeight()
		return weightInitial + (weight - weightInitial)*min((clock() - weightFadeStart)/fadeTime, 1)
	end

	self._startTime = startTime
	reset()
	local step = @native function(delta)
		local now = clock()
		local netWeight = getCurrentTotalWeight()
		if length == 0 then
			for _, jointName in jointNames do
				local pose = keyframes[jointName][1]
				transforms[jointName] = pose and pose.CFrame or cframeIdentity
			end
			return transforms, netWeight
		end

		local inc = delta*self.Speed
		timePosition += inc

		local trueTimePosition = self.TimePosition + inc

		if trueTimePosition ~= timePosition then -- timeposition has been changed
			timePosition = self.TimePosition
			-- reset indexes to allow the loops below to go back up to the proper index
			reset()
			-- place incrementing indexes at appropriate spots
			for i, time in keyframeTimes do
				if time > timePosition then
					nextPassKeyframeIdx = i
					break
				end
			end
			for i, time in markerTimes do
				if time > timePosition then
					nextPassMarkerIdx = i
					break
				end
			end
			timePosition = trueTimePosition
		else
			self.TimePosition = timePosition
		end

		if timePosition > length then
			if self.Looped then
				timePosition %= length
				nextPassKeyframeIdx = 1
				nextPassMarkerIdx = 1
				reset()
				didLoopEvent:Fire()
			else
				-- added these to account for ending markers n stuff
				self.TimePosition = length
				if hasNamedKeyframes then
					local nextKeyframeTime = keyframeTimes[nextPassKeyframeIdx]
					if nextKeyframeTime then
						if timePosition >= nextKeyframeTime then
							repeat
								keyframeReachedEvent:Fire(keyframeNames[nextPassKeyframeIdx])
								nextPassKeyframeIdx += 1
							until not keyframeTimes[nextPassKeyframeIdx] or keyframeTimes[nextPassKeyframeIdx] > timePosition
						end
					end
				end
				if hasNamedMarkers then
					local nextMarkerTime = markerTimes[nextPassMarkerIdx]
					if nextMarkerTime then
						if timePosition >= nextMarkerTime then
							repeat
								local event = markerReachedSignals[markerNames[nextPassMarkerIdx]]
								if event then
									event:Fire()
								end
								nextPassMarkerIdx += 1
							until not markerTimes[nextPassMarkerIdx] or markerTimes[nextPassMarkerIdx] > timePosition
						end
					end
				end
				self.TimePosition = 0
				self:Stop(0.5)
				return
			end
		end
		self.TimePosition = timePosition

		-- incrementing indexes instead of linear search so that it doesnt have
		-- to linear search on potentially massive arrays every frame

		if hasNamedKeyframes then
			local nextKeyframeTime = keyframeTimes[nextPassKeyframeIdx]
			if nextKeyframeTime then
				if timePosition >= nextKeyframeTime then
					repeat
						keyframeReachedEvent:Fire(keyframeNames[nextPassKeyframeIdx])
						nextPassKeyframeIdx += 1
					until not keyframeTimes[nextPassKeyframeIdx] or keyframeTimes[nextPassKeyframeIdx] > timePosition
				end
			end
		end

		if hasNamedMarkers then
			local nextMarkerTime = markerTimes[nextPassMarkerIdx]
			if nextMarkerTime then
				if timePosition >= nextMarkerTime then
					repeat
						local event = markerReachedSignals[markerNames[nextPassMarkerIdx]]
						if event then
							event:Fire()
						end
						nextPassMarkerIdx += 1
					until not markerTimes[nextPassMarkerIdx] or markerTimes[nextPassMarkerIdx] > timePosition
				end
			end
		end

		for _, jointName in jointNames do
			local poses = keyframes[jointName]
			if #poses == 0 then
				transforms[jointName] = cframeIdentity
				continue
			end

			local lastPose = lastPoses[jointName]
			local nextPose = nextPoses[jointName]
			local poseIdx = poseIndexes[jointName]
			local nextPoseIdx = nextPoseIndexes[jointName]
			local numPoses = #poses

			-- same incrementing index logic as the keyframereached and marker logic
			-- above, just with a lot more values involved

			if nextPose and timePosition > nextPose.time then
				repeat
					poseIdx = nextPoseIdx
					nextPoseIdx += 1
				until not poses[nextPoseIdx] or poses[nextPoseIdx].time >= timePosition
				lastPose = poses[poseIdx]
				nextPose = poses[nextPoseIdx]
				lastPoses[jointName] = lastPose
				nextPoses[jointName] = nextPose
				poseIndexes[jointName] = poseIdx
				nextPoseIndexes[jointName] = nextPoseIdx
			end
			if not nextPose or lastPose == nextPose then
				transforms[jointName] = lastPose.cframe
			else
				local dt = (timePosition - lastPose.time)/(nextPose.time - lastPose.time)
				transforms[jointName] = Lerp(lastPose.cframe, nextPose.cframe, math.min(getLerpAlpha(dt, nextPose.easingStyle, nextPose.easingDirection),1))
			end
		end
		return transforms, netWeight
	end

	local setWeight = @native function(newWeight, newFadeTime)
		weightInitial = getCurrentTotalWeight()
		weight = newWeight
		weightFadeStart = clock()
		fadeTime = newFadeTime or 0.1
		self.Weight = newWeight
	end

	self.IsPlaying = true
	self._step = step
	self._setWeight = setWeight
	self._parent.AnimationPlayed:Fire(self)
end

@native function AnimationTrack:_fadeOut(fadeTime)
	local initCFrames = table.clone(self._transforms)
	local startTime = clock()
	local function step()
		local elapsed = clock() - startTime
		local newTransforms = {}
		local a = min(elapsed/fadeTime, 1)
		if a == 1 then
			self.Ended:Fire()
			if self._step == step then
				self._step = nil
				self._setWeight = nil
			end
			return
		end
		for jointName, initCF in initCFrames do
			newTransforms[jointName] = Lerp(initCF, cframeIdentity, math.min(a,1))
		end
		self._transforms = newTransforms
		return {}, self.Weight*(1 - a)
	end
	self._step = step
end

@native function AnimationTrack:Stop(fadeTime)
	if not self.IsPlaying then
		return
	end
	fadeTime = fadeTime or 0.5
	self.IsPlaying = false
	self.Stopped:Fire()
	self._step = nil
	self._startTime = nil
	if fadeTime > 0 then
		self:_fadeOut(fadeTime)
	else
		self.Ended:Fire()
	end
end

@native function AnimationTrack:Destroy()
	assert(not self._destroyed, "cannot destroy already destroyed AnimationTrack")
	self._destroyed = true
	self:Stop()
	self.DidLoop:Destroy()
	self.Stopped:Destroy()
	self.Ended:Destroy()
	self.KeyframeReached:Destroy()
	for _, signal in self._markerReachedSignals do
		signal:Destroy()
	end
	table.remove(self._parent._animations, table.find(self._parent._animations, self))
end

@native function AnimationTrack.new(parent, keyframeSequence)
	local self = setmetatable({}, AnimationTrack)

	self.IsPlaying = false
	self.Length = 0
	self.Looped = keyframeSequence.Loop
	self.Speed = 1
	self.TimePosition = 0
	self.Weight = 1
	self.Priority = keyframeSequence.Priority

	self.Name = keyframeSequence.Name

	self.DidLoop = Signal("DidLoop")
	self.Ended = Signal("Ended")
	self.KeyframeReached = Signal("KeyframeReached")
	self.Stopped = Signal("Stopped")

	self._parent = parent
	self._keyframeSequence = keyframeSequence
	self._destroyed = false
	self._keyframes = {}
	self._keyframeTimes = {}
	self._keyframeNamesOrdered = {}
	self._markerTimes = {}
	self._markerNamesOrdered = {}
	self._jointNames = {}
	self._transforms = {} -- processed transforms via _step
	self._step = nil -- function that the Play() method creates so that much is localized, minizming index calls that would otherwise be needed in an object private methods approach
	self._setWeight = nil -- function that the Play() method creats that AdjustWeight() interfaces to be able to manipulate data only accessible to _step

	self._markerReachedSignals = {}

	-- reference lists for final sorting
	local keyframeTimes = {}
	local markerTimes = {}
	
	for _, keyframe in keyframeSequence:QueryDescendants(">Keyframe") do
		self.Length = math.max(self.Length, keyframe.time)
		if keyframe.Name ~= "Keyframe" then
			keyframeTimes[keyframe.Name] = keyframe.time
			table.insert(self._keyframeTimes, keyframe.time)
			table.insert(self._keyframeNamesOrdered, keyframe.Name)
		end
		for _, marker in keyframe:GetMarkers() do
			markerTimes[marker.Name] = keyframe.time
			table.insert(self._markerTimes, keyframe.time)
			table.insert(self._markerNamesOrdered, marker.Name)
		end
		local rootPose = keyframe:QueryDescendants(">Pose")[1]
		if not rootPose then
			continue
		end
		for _, pose in rootPose:QueryDescendants("Pose") do
			if pose.Weight == 0 then
				continue
			end
			local keyframes = self._keyframes[pose.Name]
			if not keyframes then
				keyframes = {}
				self._keyframes[pose.Name] = keyframes
				self._transforms[pose.Name] = CFrame.identity
				table.insert(self._jointNames, pose.Name)
			end
			table.insert(keyframes, {
				time = keyframe.Time,
				cframe = pose.CFrame,
				easingDirection = pose.EasingDirection.Value,
				easingStyle = pose.EasingStyle.Value,
				weight = pose.Weight
			})
		end
	end

	-- not confident that the above will have it sort it so im gonna sort it lol

	table.sort(self._keyframeTimes, function(a, b) return a < b end)
	table.sort(self._markerTimes, function(a, b) return a < b end)
	table.sort(self._keyframeNamesOrdered, function(a, b)
		return keyframeTimes[a] < keyframeTimes[b]
	end)
	table.sort(self._markerNamesOrdered, function(a, b)
		return markerTimes[a] < markerTimes[b]
	end)

	for _, jointKeyframes in self._keyframes do
		table.sort(jointKeyframes, function(a, b)
			return a.time < b.time
		end)
		if self.Looped and #jointKeyframes > 1 then
			-- pad the start with the last keyframe and the end with the first key frame to seemlessly loop it
			local first = table.clone(jointKeyframes[1])
			local last = table.clone(jointKeyframes[#jointKeyframes])
			first.time = self.Length + first.time
			last.time = last.time - self.Length
			table.insert(jointKeyframes, first)
			table.insert(jointKeyframes, 1, last)
		end
	end

	return self
end

local function assertIsObject(self)
	assert(self ~= Animator, "cannot call object method on static class")
end

@native function Animator:LoadAnimation(keyframeSequence)
	assertIsObject(self)
	local animations = self._animations
	for _, animation in animations do
		if animation._keyframeSequence == keyframeSequence then
			return animation
		end
	end
	local animationTrack = AnimationTrack.new(self, keyframeSequence)
	table.insert(animations, animationTrack)
	return animationTrack
end

@native function Animator:GetPlayingAnimationTracks()
	local tracks = {}
	for _, animationTrack in self._animations do
		if animationTrack.IsPlaying then
			table.insert(tracks, animationTrack)
		end
	end
	return tracks
end

@native function Animator:Destroy()
	assertIsObject(self)
	assert(not self._destroyed, "cannot destroy already destroyed Animator")
	self._destroyed = true
	for _, animation in self._animations do
		animation:Destroy()
	end
	for _, stopTracker in self._jointTrackers do
		stopTracker()
	end
	table.clear(self._animations)
	table.clear(self._jointTrackers)
	self._stepped:Disconnect()
	self._descendantAdded:Disconnect()
	self._descendantRemoving:Disconnect()
	self._stepped = nil
	self._descendantAdded = nil
	self._descendantRemoving = nil
	setmetatable(self, nil)
end

-- for mimicking naming behavior of poses

local Part1Tracker = @native function(part, onSet)
	local connection = part:GetPropertyChangedSignal("Name"):Connect(function()
		onSet(part.Name)
	end)
	return function()
		connection:Disconnect()
	end
end

local JointTracker = @native function(joint, onSet, onUnset)
	local current
	local currentTracker
	local onPartNameChanged = @native function(name)
		onUnset(current)
		current = name
		onSet(current)
	end
	if joint.Part1 then
		current = joint.Part1.Name
		currentTracker = Part1Tracker(joint.Part1, onPartNameChanged)
	end
	local connection = joint:GetPropertyChangedSignal("Part1"):Connect(function()
		onUnset(current)
		if currentTracker then
			currentTracker()
			currentTracker = nil
		end
		if joint.Part1 then
			current = joint.Part1.Name
			onSet(current)
			currentTracker = Part1Tracker(joint.Part1, onPartNameChanged)
		end
	end)
	return function()
		connection:Disconnect()
		if currentTracker then
			currentTracker()
		end
	end
end

@native function Animator.new(humanoid): Animator
	local animator = Animators[humanoid]
	if animator then
		return animator
	end

	local self = setmetatable({}, Animator)

	-- localizing these fields to this scope so it doesnt have to index self so much
	-- every frame
	-- self._transforms is not localized because it is overwritten on each frame
	local animations = {}
	local joints = {}
	local jointTrackers = {}
	local steppedEvent = Signal("Stepped")
	local animationPlayed = Signal("AnimationPlayed")

	self.Stepped = steppedEvent
	self.AnimationPlayed = animationPlayed

	self._humanoid = humanoid
	self._destroyed = false
	self._joints = joints
	self._transforms = {} -- not localized because this table changes
	self._jointTrackers = jointTrackers
	self._animations = animations

	self._descendantAdded = nil
	self._descendantRemoving = nil

	local last = clock()
	self._stepped = RunService.Stepped:Connect(@native function()
		local now = clock()
		local delta = now - last -- stepped delta is throttled
		last = now
		local currentTransforms = self._transforms

		local newTransforms = {}
		local priorities = {}
		for jointName in joints do
			priorities[jointName] = 0
		end
		for _, animation in animations do
			if not animation._step then
				continue
			end
			local priority = animation.Priority.Value
			local transforms, weight = animation._step(delta)
			if not transforms then
				continue
			end
			for jointName, cf in transforms do
				if not joints[jointName] then
					continue
				end
				local override = false
				if priority >= priorities[jointName] then
					priorities[jointName] = priority
					override = true
				end
				local other = newTransforms[jointName]
				if override then
					local startTime = animation._startTime
					if other then
						-- hope this works!
						local a = priority == other[3] and weight/(weight + other[4]) or weight
						local cfFinal = Lerp(other[2], cf, math.min(a,1)) 
						newTransforms[jointName] = {startTime, cfFinal, priority, weight}
					else
						newTransforms[jointName] = {startTime, cf, priority, weight}
					end
				end
			end
		end
		-- finalize
		for jointName, cfData in newTransforms do
			newTransforms[jointName] = cfData[2]
		end
		for jointName, joint in joints do
			local cf = newTransforms[jointName] or cframeIdentity
			local old = currentTransforms[jointName]
			
			if old then
				joint.joint.C0 = Lerp(joint.joint.C0, joint.c0 * cf, math.min(delta * 20, 1))
			else
				joint.joint.C0 = joint.c0 * cf
			end
		end
		self._transforms = newTransforms
		steppedEvent:Fire(newTransforms)
	end)

	local newDescendant = function(joint)
		if joint.ClassName ~= "Motor6D" then
			return
		end
		local me = {
			joint = joint,
			c0 = joint.C0
		}
		if joint.Part1 then
			joints[joint.Part1.Name] = me
			self._transforms[joint.Part1.Name] = cframeIdentity
		end
		self._jointTrackers[joint] = JointTracker(joint, function(name)
			joints[name] = me
			if not self._transforms[joint.Part1.Name] then
				self._transforms[joint.Part1.Name] = cframeIdentity
			end
		end, function(name)
			joints[name] = nil
		end)
	end

	for _, joint in humanoid.Parent:QueryDescendants("Motor6D") do
		newDescendant(joint)
	end

	self._descendantAdded = humanoid.Parent.DescendantAdded:Connect(newDescendant)
	self._descendantRemoving = humanoid.Parent.DescendantRemoving:Connect(function(joint)
		if joint.ClassName ~= "Motor6D" then
			return
		end
		if joint.Part1 then
			steppedEvent[joint.Part1.Name] = nil
		end
		jointTrackers[joint]() -- stop tracker
		jointTrackers[joint] = nil
	end)

	Animators[humanoid] = self

	return self
end

return Animator
