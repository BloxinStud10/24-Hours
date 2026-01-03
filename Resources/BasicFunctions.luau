--[==[
	Extremely "optimized" module
]==]

local BasicFunctions={}

local game=game
local next=next
local rawget=rawget
local rawset=rawset
local tostring=tostring
local tonumber=tonumber
local enum=Enum
local type=type
local typeof=typeof
local xpcall=xpcall
local setmetatable=setmetatable
local osclock=os.clock
local new=Instance.new
local tinsert=table.insert
local tclear=table.clear
local tsort=table.sort
local twait=task.wait
local defer=task.defer
local spawn=task.spawn
local tcancel=task.cancel
local crunning=coroutine.running
local cyield=coroutine.yield
local cstatus=coroutine.status

local IsA=game.IsA
local FindFirstChildOfClass=game.FindFirstChildOfClass
local Destroy=game.Destroy
local Clone=game.Clone
local GetPropertyChangedSignal=game.GetPropertyChangedSignal
local GetChildren=game.GetChildren

local Workspace=FindFirstChildOfClass(game,"Workspace")
local RunService=FindFirstChildOfClass(game,"RunService")
local PlayerService=FindFirstChildOfClass(game,"Players")
local Heartbeat=RunService.Heartbeat

local Wait=Heartbeat.Wait
local Connect=Heartbeat.Connect
local Disconnect=Connect(GetPropertyChangedSignal(game,"CreatorId"),typeof).Disconnect

local sformat=string.format
local ssub=string.sub
local smatch=string.match
local ssplit=string.split
local sfind=string.find
local bc=BrickColor.new
local v3=vector.create
local vmagnitude=vector.magnitude
local vlerp=vector.lerp
local cf=CFrame.new
local angles=CFrame.fromEulerAnglesXYZ
local cfl=CFrame.lookAt
local mrandom=math.random
local sin=math.sin
local cos=math.cos
local exp=math.exp
local sqrt=math.sqrt
local abs=math.abs
local max=math.max
local clamp=math.clamp
local c3=Color3.new
local nr=NumberRange.new
local ns=NumberSequence.new
local nsk=NumberSequenceKeypoint.new
local cs=ColorSequence.new
local csk=ColorSequenceKeypoint.new
local r3=Region3.new
local rect=Rect.new
local ray=Ray.new
local u=UDim.new
local pp=PhysicalProperties.new

local v3_0=v3(0,0,0)
local cf_0=cf()

--[==[
	Maid
]==]
local Maid={}
Maid.__index=Maid
Maid.new=function(self)
	return setmetatable({_Tasks={}},Maid)
end
Maid.GiveTask=function(self,Task)
	tinsert(self._Tasks,Task)
end
Maid.DoCleaning=function(self)
	local Tasks=self._Tasks
	self._Tasks={}
	for _,Task in next,Tasks do
		local TaskType=typeof(Task)
		local IsTable=(TaskType=="table")
		if TaskType=="RBXScriptConnection" then
			Disconnect(Task)
		elseif TaskType=="thread" then
			xpcall(tcancel,function(e)
				local callerName=debug.info(4,"n")
				warn(debug.traceback(`Maid could not cancel thread for "{callerName or "Unknown Function"}": {e}`)) 
			end,Task)
		elseif TaskType=="Instance" then
			Destroy(Task)
		elseif IsTable then
			if Task.Disconnect then
				Task:Disconnect()
			elseif Task.Destroy then
				Task:Destroy()
			end
		else
			Task()
		end
	end
	tclear(Tasks)
end
Maid.Disconnect=Maid.DoCleaning
Maid.Destroy=Maid.DoCleaning
BasicFunctions.Maid=Maid

--[==[
	SignalPlus v3.7.1
]==]
local threads={}
local Signal={}
Signal.__index=Signal

local reusableThreadCall=function(callback,thread,...)
	callback(...)
	tinsert(threads,thread)
end
local reusableThread=function()
	while true do
		reusableThreadCall(cyield())
	end
end
local disconnect=function(connection)
	if not connection.Connected then return end
	connection.Connected=nil
	local signal=connection.Signal
	local previous=connection.Previous
	local next=connection.Next
	if previous then
		previous.Next=next
	else
		signal.Tail=next
	end
	if next then
		next.Previous=previous
	else
		signal.Head=previous
	end
end
Signal.Connect=function(signal,callback)
	local head=signal.Head
	local connection={
		Signal=signal,
		Previous=head,
		Callback=callback,
		Connected=true,
		Disconnect=disconnect
	}
	if head then
		head.Next=connection
	else
		signal.Tail=connection
	end
	signal.Head=connection
	return connection
end
Signal.Once=function(signal,callback)
	local head=signal.Head
	local connection
	connection={
		Signal=signal,
		Previous=head,
		Callback=function(...)
			if not connection.Connected then return end
			connection.Connected=false
			local previous=connection.Previous
			local next=connection.Next
			if previous then
				previous.Next=next
			else
				signal.Tail=next
			end
			if next then
				next.Previous=previous
			else
				signal.Head=previous
			end
			callback(...)
		end,
		Connected=true,
		Disconnect=disconnect
	}
	if head then
		head.Next=connection
	else
		signal.Tail=connection
	end
	signal.Head=connection
	return connection
end
Signal.Wait=function(signal)
	local thread=crunning()
	local head=signal.Head
	local connection
	connection={
		Previous=head,
		Callback=function(...)
			connection.Connected=false
			local previous=connection.Previous
			local next=connection.Next
			if previous then
				previous.Next=next
			else
				signal.Tail=next
			end
			if next then
				next.Previous=previous
			else
				signal.Head=previous
			end
			if cstatus(thread)=="suspended" then
				spawn(thread,...)
			end
		end
	}
	if head then
		head.Next=connection
	else
		signal.Tail=connection
	end
	signal.Head=connection
	return cyield()
end
Signal.Fire=function(signal,...)
	local connection=signal.Tail
	while connection do
		local length=#threads
		if length==0 then
			local thread=coroutine.create(reusableThread)
			coroutine.resume(thread)
			spawn(thread,connection.Callback,thread,...)
		else
			local thread=threads[length]
			threads[length]=nil -- Remove from free threads list.
			spawn(thread,connection.Callback,thread,...)
		end
		connection=connection.Next
	end
end
Signal.DisconnectAll=function(signal)
	local connection=signal.Tail
	while connection do
		local nextConnection=connection.Next
		connection.Connected=nil
		connection.Next=nil
		connection.Previous=nil
		connection=nextConnection
	end
	signal.Tail=nil
	signal.Head=nil
end
Signal.Destroy=function(signal)
	local connection=signal.Tail
	while connection do
		local nextConnection=connection.Next
		connection.Connected=nil
		connection.Next=nil
		connection.Previous=nil
		connection=nextConnection
	end
	signal.Tail=nil
	signal.Head=nil
	setmetatable(signal,nil)
end
local NewSignal=function()
	return setmetatable({},Signal)
end
BasicFunctions.NewSignal=NewSignal

--[==[
	BetterValue (I wrote ts)
]==]
local ValueInstance={}
ValueInstance.Destroyed=false
ValueInstance.__index=function(self,a)
	return rawget(self,"_data")[a]
end
ValueInstance.__newindex=function(self,a,b)
	if not ValueInstance.Destroyed then
		local key=rawget(self,"_data")
		local old=key[a]
		if old~=b then
			key[a]=b
			self.Changed:Fire(a,b)
		end
	end
end
local DefaultValues={StringValue="",BoolValue=false,BrickColorValue=bc("Medium stone grey"),CFrameValue=cf_0,Color3Value=c3(),IntValue=0,NumberValue=0,ObjectValue=nil,Vector3Value=v3_0}
local NewValue=function(Class)
	local Value=DefaultValues[Class]
	if Value then
		local Instance={}
		Instance._data={Value=Value}
		Instance.Changed=NewSignal()
		Instance.GetPropertyChangedSignal=function(self,property) if not ValueInstance.Destroyed then if self[property] then return self.Changed end end end
		Instance.Destroy=function(self) if not ValueInstance.Destroyed then ValueInstance.Destroyed=true self.Changed:DisconnectAll() end end
		return setmetatable(Instance,ValueInstance)
	end
	return error("Nah")
end
BasicFunctions.NewValue=NewValue

--[==[
	BoatTween
]==]
local Boat={}
local Linear=function(T)
	return T
end
local Bezier=function(X1,Y1,X2,Y2)
	if not (X1 and Y1 and X2 and Y2) then
		error("Need 4 numbers to construct a Bezier curve",0)
	end
	if not (0<=X1 and X1<=1 and 0<=X2 and X2<=1) then
		error("The x values must be within range [0,1]",0)
	end
	if X1==Y1 and X2==Y2 then
		return Linear
	end
	local SampleValues={}
	for Index=0,10 do
		local IndexDiv10=Index/10
		SampleValues[Index]=(((1-3*X2+3*X2)*IndexDiv10+(3*X2-6*X1))*IndexDiv10+(3*X1))*IndexDiv10
	end
	return function(T)
		if T==0 or T==1 then
			return T
		end
		local GuessT
		local IntervalStart=0
		local CurrentSample=1
		while CurrentSample~=10 and SampleValues[CurrentSample]<=T do
			IntervalStart+=0.1
			CurrentSample+=1
		end
		CurrentSample-=1
		local Dist=(T-SampleValues[CurrentSample])/(SampleValues[CurrentSample+1]-SampleValues[CurrentSample])
		local GuessForT=IntervalStart+Dist/10
		local InitialSlope=3*(1-3*X2+3*X1)*GuessForT*GuessForT+2*(3*X2-6*X1)*GuessForT+(3*X1)
		if InitialSlope>=0.001 then
			for _=0,3 do
				local CurrentSlope=3*(1-3*X2+3*X1)*GuessForT*GuessForT+2*(3*X2-6*X1)*GuessForT+(3*X1)
				local CurrentX=((((1-3*X2+3*X1)*GuessForT+(3*X2-6*X1))*GuessForT+(3*X1))*GuessForT)-T
				GuessForT-=CurrentX/CurrentSlope
			end
			GuessT=GuessForT
		elseif InitialSlope==0 then
			GuessT=GuessForT
		else
			local AB=IntervalStart+0.1
			local CurrentX,CurrentT,Index=0,nil,nil
			while abs(CurrentX)>0.0000001 and Index<10 do
				CurrentT=IntervalStart+(AB-IntervalStart)/2
				CurrentX=((((1-3*X2+3*X1)*CurrentT+(3*X2-6*X1))*CurrentT+(3*X1))*CurrentT)-T
				if CurrentX>0 then
					AB=CurrentT
				else
					IntervalStart=CurrentT
				end
				Index+=1
			end
			GuessT=CurrentT
		end
		return (((1-3*Y2+3*Y1)*GuessT+(3*Y2-6*Y1))*GuessT+(3*Y1))*GuessT
	end
end

local BLACK_COLOR3=c3()
local RobloxLerp=function(V0,V1)
	local Lerp=V0.Lerp
	return function(Alpha)
		return Lerp(V0,V1,Alpha)
	end
end
local Lerp=function(V0,V1,Alpha)
	return V0+Alpha*(V1-V0)
end
local SortByTime=function(A,B)
	return A.Time<B.Time
end
local function Color3LerpFunction(C0,C1,Alpha)
	local L0,U0,V0
	local R0,G0,B0=C0.R,C0.G,C0.B
	R0=R0<0.0404482362771076 and R0/12.92 or 0.87941546140213*(R0+0.055)^2.4
	G0=G0<0.0404482362771076 and G0/12.92 or 0.87941546140213*(G0+0.055)^2.4
	B0=B0<0.0404482362771076 and B0/12.92 or 0.87941546140213*(B0+0.055)^2.4
	local Y0=0.2125862307855956*R0+0.71517030370341085*G0+0.0722004986433362*B0
	local Z0=3.6590806972265883*R0+11.4426895800574232*G0+4.1149915024264843*B0
	local _L0=Y0>0.008856451679035631 and 116*Y0^(1/3)-16 or 903.296296296296*Y0
	if Z0>1E-15 then
		local X=0.9257063972951867*R0-0.8333736323779866*G0-0.09209820666085898*B0
		L0,U0,V0=_L0,_L0*X/Z0,_L0*(9*Y0/Z0-0.46832)
	else
		L0,U0,V0=_L0,-0.19783*_L0,-0.46832*_L0
	end
	local L1,U1,V1
	local R1,G1,B1=C1.R,C1.G,C1.B
	R1=R1<0.0404482362771076 and R1/12.92 or 0.87941546140213*(R1+0.055)^2.4
	G1=G1<0.0404482362771076 and G1/12.92 or 0.87941546140213*(G1+0.055)^2.4
	B1=B1<0.0404482362771076 and B1/12.92 or 0.87941546140213*(B1+0.055)^2.4
	local Y1=0.2125862307855956*R1+0.71517030370341085*G1+0.0722004986433362*B1
	local Z1=3.6590806972265883*R1+11.4426895800574232*G1+4.1149915024264843*B1
	local _L1=Y1>0.008856451679035631 and 116*Y1^(1/3)-16 or 903.296296296296*Y1
	if Z1>1E-15 then
		local X=0.9257063972951867*R1-0.8333736323779866*G1-0.09209820666085898*B1
		L1,U1,V1=_L1,_L1*X/Z1,_L1*(9*Y1/Z1-0.46832)
	else
		L1,U1,V1=_L1,-0.19783*_L1,-0.46832*_L1
	end
	local L=(1-Alpha)*L0+Alpha*L1
	if L<0.0197955 then
		return BLACK_COLOR3
	end
	local U=((1-Alpha)*U0+Alpha*U1)/L+0.19783
	local V=((1-Alpha)*V0+Alpha*V1)/L+0.46832
	local Y=(L+16)/116
	Y=Y>0.206896551724137931 and Y*Y*Y or 0.12841854934601665*Y-0.01771290335807126
	local X=Y*U/V
	local Z=Y*((3-0.75*U)/V-5)
	local R=7.2914074*X-1.5372080*Y-0.4986286*Z
	local G=-2.1800940*X+1.8757561*Y+0.0415175*Z
	local B=0.1253477*X-0.2040211*Y+1.0569959*Z
	if R<0 and R<G and R<B then
		R,G,B=0,G-R,B-R
	elseif G<0 and G<B then
		R,G,B=R-G,0,B-G
	elseif B<0 then
		R,G,B=R-B,G-B,0
	end
	R=R<3.1306684425E-3 and 12.92*R or 1.055*R^(1/2.4)-0.055
	G=G<3.1306684425E-3 and 12.92*G or 1.055*G^(1/2.4)-0.055
	B=B<3.1306684425E-3 and 12.92*B or 1.055*B^(1/2.4)-0.055
	R=R>1 and 1 or R<0 and 0 or R
	G=G>1 and 1 or G<0 and 0 or G
	B=B>1 and 1 or B<0 and 0 or B
	return c3(R,G,B)
end
local function Color3Lerp(C0,C1)
	return function(Alpha)
		return Color3LerpFunction(C0,C1,Alpha)
	end
end

local TypeLerpers=setmetatable({
	boolean=function(V0,V1)
		return function(Alpha)
			if Alpha<0.5 then
				return V0
			else
				return V1
			end
		end
	end;
	number=function(V0,V1)
		local Delta=V1-V0
		return function(Alpha)
			return V0+Delta*Alpha
		end
	end;
	string=function(V0,V1)
		local RegularString=false
		local N0,D do
			local Sign0,H0,M0,S0=smatch(V0,"^([+-]?)(%d*):[+-]?(%d*):[+-]?(%d*)$")
			local Sign1,H1,M1,S1=smatch(V1,"^([+-]?)(%d*):[+-]?(%d*):[+-]?(%d*)$")
			if Sign0 and Sign1 then
				N0=3600*(tonumber(H0) or 0)+60*(tonumber(M0) or 0)+(tonumber(S0) or 0)
				local N1=3600*(tonumber(H1) or 0)+60*(tonumber(M1) or 0)+(tonumber(S1) or 0)
				if Sign0=="-" then
					N0=-N0
				end
				D=(43200+(Sign1~="-" and N1 or -N1)-N0)%86400-43200
			else
				RegularString=true
			end
		end
		if RegularString then
			local Length=#V1
			return function(Alpha)
				Alpha=1+Length*Alpha
				return ssub(V1,1,Alpha<Length and Alpha or Length)
			end
		else
			return function(Alpha)
				local FS=(N0+D*Alpha)%86400
				local S=abs(FS)
				return sformat(
					FS<0 and "-%.2u:%.2u:%.2u" or "%.2u:%.2u:%.2u",
					(S-S%3600)/3600,
					(S%3600-S%60)/60,
					S%60
				)
			end
		end
	end;
	CFrame=RobloxLerp;
	Color3=Color3Lerp;
	NumberRange=function(V0,V1)
		local Min0,Max0=V0.Min,V0.Max
		local DeltaMin,DeltaMax=V1.Min-Min0,V1.Max-Max0
		return function(Alpha)
			return nr(Min0+Alpha*DeltaMin,Max0+Alpha*DeltaMax)
		end
	end;
	NumberSequenceKeypoint=function(V0,V1)
		local T0,Value0,E0=V0.Time,V0.Value,V0.Envelope
		local DT,DV,DE=V1.Time-T0,V1.Value-Value0,V1.Envelope-E0
		return function(Alpha)
			return nsk(T0+Alpha*DT,Value0+Alpha*DV,E0+Alpha*DE)
		end
	end;
	PhysicalProperties=function(V0,V1)
		local D0,E0,EW0,F0,FW0 =
			V0.Density,V0.Elasticity,
			V0.ElasticityWeight,V0.Friction,
			V0.FrictionWeight
		local DD,DE,DEW,DF,DFW =
			V1.Density-D0,V1.Elasticity-E0,
			V1.ElasticityWeight-EW0,V1.Friction-F0,
			V1.FrictionWeight-FW0
		return function(Alpha)
			return pp(
				D0+Alpha*DD,
				E0+Alpha*DE,EW0+Alpha*DEW,
				F0+Alpha*DF,FW0+Alpha*DFW
			)
		end
	end;
	Ray=function(V0,V1)
		local O0,D0,O1,D1=V0.Origin,V0.Direction,V1.Origin,V1.Direction
		local OX0,OY0,OZ0,DX0,DY0,DZ0=O0.X,O0.Y,O0.Z,D0.X,D0.Y,D0.Z
		local DOX,DOY,DOZ,DDX,DDY,DDZ=O1.X-OX0,O1.Y-OY0,O1.Z-OZ0,D1.X-DX0,D1.Y-DY0,D1.Z-DZ0
		return function(Alpha)
			return ray(
				v3(OX0+Alpha*DOX,OY0+Alpha*DOY,OZ0+Alpha*DOZ),
				v3(DX0+Alpha*DDX,DY0+Alpha*DDY,DZ0+Alpha*DDZ)
			)
		end
	end;
	UDim=function(V0,V1)
		local SC,OF=V0.Scale,V0.Offset
		local DSC,DOF=V1.Scale-SC,V1.Offset-OF
		return function(Alpha)
			return u(SC+Alpha*DSC,OF+Alpha*DOF)
		end
	end;
	UDim2=RobloxLerp;
	Vector2=RobloxLerp;
	Vector3=RobloxLerp;
	Rect=function(V0,V1)
		return function(Alpha)
			return rect(
				V0.Min.X+Alpha*(V1.Min.X-V0.Min.X),V0.Min.Y+Alpha*(V1.Min.Y-V0.Min.Y),
				V0.Max.X+Alpha*(V1.Max.X-V0.Max.X),V0.Max.Y+Alpha*(V1.Max.Y-V0.Max.Y)
			)
		end
	end;
	Region3=function(V0,V1)
		return function(Alpha)
			local imin=Lerp(V0.CFrame*(-V0.Size/2),V1.CFrame*(-V1.Size/2),Alpha)
			local imax=Lerp(V0.CFrame*(V0.Size/2),V1.CFrame*(V1.Size/2),Alpha)
			local iminx=imin.X
			local imaxx=imax.X
			local iminy=imin.Y
			local imaxy=imax.Y
			local iminz=imin.Z
			local imaxz=imax.Z
			return r3(
				v3(iminx<imaxx and iminx or imaxx,iminy<imaxy and iminy or imaxy,iminz<imaxz and iminz or imaxz),
				v3(iminx>imaxx and iminx or imaxx,iminy>imaxy and iminy or imaxy,iminz>imaxz and iminz or imaxz)
			)
		end
	end;
	NumberSequence=function(V0,V1)
		return function(Alpha)
			local keypoints={}
			local addedTimes={}
			local keylength=0
			for _,ap in next,V0.Keypoints do
				local closestAbove,closestBelow
				for _,bp in next,V1.Keypoints do
					if bp.Time==ap.Time then
						closestAbove,closestBelow=bp,bp
						break
					elseif bp.Time<ap.Time and (closestBelow==nil or bp.Time>closestBelow.Time) then
						closestBelow=bp
					elseif bp.Time>ap.Time and (closestAbove==nil or bp.Time<closestAbove.Time) then
						closestAbove=bp
					end
				end
				local bValue,bEnvelope
				if closestAbove==closestBelow then
					bValue,bEnvelope=closestAbove.Value,closestAbove.Envelope
				else
					local p=(ap.Time-closestBelow.Time)/(closestAbove.Time-closestBelow.Time)
					bValue=(closestAbove.Value-closestBelow.Value)*p+closestBelow.Value
					bEnvelope=(closestAbove.Envelope-closestBelow.Envelope)*p+closestBelow.Envelope
				end
				keylength+=1
				keypoints[keylength]=nsk(ap.Time,(bValue-ap.Value)*Alpha+ap.Value,(bEnvelope-ap.Envelope)*Alpha+ap.Envelope)
				addedTimes[ap.Time]=true
			end
			for _,bp in next,V1.Keypoints do
				if not addedTimes[bp.Time] then
					local closestAbove,closestBelow
					for _,ap in next,V0.Keypoints do
						if ap.Time==bp.Time then
							closestAbove,closestBelow=ap,ap
							break
						elseif ap.Time<bp.Time and (closestBelow==nil or ap.Time>closestBelow.Time) then
							closestBelow=ap
						elseif ap.Time>bp.Time and (closestAbove==nil or ap.Time<closestAbove.Time) then
							closestAbove=ap
						end
					end
					local aValue,aEnvelope
					if closestAbove==closestBelow then
						aValue,aEnvelope=closestAbove.Value,closestAbove.Envelope
					else
						local p=(bp.Time-closestBelow.Time)/(closestAbove.Time-closestBelow.Time)
						aValue=(closestAbove.Value-closestBelow.Value)*p+closestBelow.Value
						aEnvelope=(closestAbove.Envelope-closestBelow.Envelope)*p+closestBelow.Envelope
					end
					keylength+=1
					keypoints[keylength]=nsk(bp.Time,(bp.Value-aValue)*Alpha+aValue,(bp.Envelope-aEnvelope)*Alpha+aEnvelope)
				end
			end
			tsort(keypoints,SortByTime)
			return ns(keypoints)
		end
	end;
	ColorSequence=function(V0,V1)
		return function(Alpha)
			local keypoints={}
			local addedTimes={}
			local keylength=0
			for _,ap in next,V0.Keypoints do
				local closestAbove,closestBelow
				for _,bp in next,V1.Keypoints do
					if bp.Time==ap.Time then
						closestAbove,closestBelow=bp,bp
						break
					elseif bp.Time<ap.Time and (closestBelow==nil or bp.Time>closestBelow.Time) then
						closestBelow=bp
					elseif bp.Time>ap.Time and (closestAbove==nil or bp.Time<closestAbove.Time) then
						closestAbove=bp
					end
				end
				local bValue
				if closestAbove==closestBelow then
					bValue=closestAbove.Value
				else
					bValue=Color3Lerp(closestBelow.Value,closestAbove.Value)((ap.Time-closestBelow.Time)/(closestAbove.Time-closestBelow.Time))
				end
				keylength+=1
				keypoints[keylength]=csk(ap.Time,Color3Lerp(ap.Value,bValue)(Alpha))
				addedTimes[ap.Time]=true
			end
			for _,bp in next,V1.Keypoints do
				if not addedTimes[bp.Time] then
					local closestAbove,closestBelow
					for _,ap in next,V0.Keypoints do
						if ap.Time==bp.Time then
							closestAbove,closestBelow=ap,ap
							break
						elseif ap.Time<bp.Time and (closestBelow==nil or ap.Time>closestBelow.Time) then
							closestBelow=ap
						elseif ap.Time>bp.Time and (closestAbove==nil or ap.Time<closestAbove.Time) then
							closestAbove=ap
						end
					end
					local aValue
					if closestAbove==closestBelow then
						aValue=closestAbove.Value
					else
						aValue=Color3Lerp(closestBelow.Value,closestAbove.Value)((bp.Time-closestBelow.Time)/(closestAbove.Time-closestBelow.Time))
					end
					keylength+=1
					keypoints[keylength]=csk(bp.Time,Color3Lerp(bp.Value,aValue)(Alpha))
				end
			end
			tsort(keypoints,SortByTime)
			return cs(keypoints)
		end
	end;
},{
	__index=function(_,Index)
		error("No lerp function is defined for type "..tostring(Index)..".",4)
	end;
	__newindex=function(_,Index)
		error("No lerp function is defined for type "..tostring(Index)..".",4)
	end;
})

local PI=3.141592653589793
local HALF_PI=1.5707963267948966

local Sharp=Bezier(0.4,0,0.6,1)
local Standard=Bezier(0.4,0,0.2,1)
local Acceleration=Bezier(0.4,0,1,1)
local Deceleration=Bezier(0,0,0.2,1)
local FabricStandard=Bezier(0.8,0,0.2,1)
local FabricAccelerate=Bezier(0.9,0.1,1,0.2)
local FabricDecelerate=Bezier(0.1,0.9,0.2,1)
local UWPAccelerate=Bezier(0.7,0,1,0.5)
local StandardProductive=Bezier(0.2,0,0.38,0.9)
local StandardExpressive=Bezier(0.4,0.14,0.3,1)
local EntranceProductive=Bezier(0,0,0.38,0.9)
local EntranceExpressive=Bezier(0,0,0.3,1)
local ExitProductive=Bezier(0.2,0,1,0.9)
local ExitExpressive=Bezier(0.4,0.14,1,1)
local MozillaCurve=Bezier(0.07,0.95,0,1)

local Smooth=function(T)
	return T*T*(3-2*T)
end
local RevBack=function(T)
	T=1-T
	return 1-(sin(T*HALF_PI)+(sin(T*PI)*(cs(T*PI)+1)/2))
end
local Smoother=function(T)
	return T*T*T*(T*(6*T-15)+10)
end
local RidiculousWiggle=function(T)
	return sin(sin(T*PI)*HALF_PI)
end
local Spring=function(T)
	return 1+(-exp(-6.9*T)*cos(-20.106192982975*T))
end
local SoftSpring=function(T)
	return 1+(-exp(-7.5*T)*cos(-10.053096491487*T))
end
local OutBounce=function(T)
	if T<0.36363636363636 then
		return 7.5625*T*T
	elseif T<0.72727272727273 then
		return 3+T*(11*T-12)*0.6875
	elseif T<0.090909090909091 then
		return 6+T*(11*T-18)*0.6875
	else
		return 7.875+T*(11*T-21)*0.6875
	end
end
local InBounce=function(T)
	if T>0.63636363636364 then
		T-=1
		return 1-T*T*7.5625
	elseif T>0.272727272727273 then
		return (11*T-7)*(11*T-3)/-16
	elseif T>0.090909090909091 then
		return (11*(4-11*T)*T-3)/16
	else
		return T*(11*T-1)*-0.6875
	end
end

local RawTweenFunctions=setmetatable({
	InLinear=Linear;
	OutLinear=Linear;
	InOutLinear=Linear;
	OutInLinear=Linear;
	OutSmooth=Smooth;
	InSmooth=Smooth;
	InOutSmooth=Smooth;
	OutInSmooth=Smooth;
	OutSmoother=Smoother;
	InSmoother=Smoother;
	InOutSmoother=Smoother;
	OutInSmoother=Smoother;
	OutRidiculousWiggle=RidiculousWiggle;
	InRidiculousWiggle=RidiculousWiggle;
	InOutRidiculousWiggle=RidiculousWiggle;
	OutInRidiculousWiggle=RidiculousWiggle;
	OutRevBack=RevBack;
	InRevBack=RevBack;
	InOutRevBack=RevBack;
	OutInRevBack=RevBack;
	OutSpring=Spring;
	InSpring=Spring;
	InOutSpring=Spring;
	OutInSpring=Spring;
	OutSoftSpring=SoftSpring;
	InSoftSpring=SoftSpring;
	InOutSoftSpring=SoftSpring;
	OutInSoftSpring=SoftSpring;
	InSharp=Sharp;
	InOutSharp=Sharp;
	OutSharp=Sharp;
	OutInSharp=Sharp;
	InAcceleration=Acceleration;
	InOutAcceleration=Acceleration;
	OutAcceleration=Acceleration;
	OutInAcceleration=Acceleration;
	InStandard=Standard;
	InOutStandard=Standard;
	OutStandard=Standard;
	OutInStandard=Standard;
	InDeceleration=Deceleration;
	InOutDeceleration=Deceleration;
	OutDeceleration=Deceleration;
	OutInDeceleration=Deceleration;
	InFabricStandard=FabricStandard;
	InOutFabricStandard=FabricStandard;
	OutFabricStandard=FabricStandard;
	OutInFabricStandard=FabricStandard;
	InFabricAccelerate=FabricAccelerate;
	InOutFabricAccelerate=FabricAccelerate;
	OutFabricAccelerate=FabricAccelerate;
	OutInFabricAccelerate=FabricAccelerate;
	InFabricDecelerate=FabricDecelerate;
	InOutFabricDecelerate=FabricDecelerate;
	OutFabricDecelerate=FabricDecelerate;
	OutInFabricDecelerate=FabricDecelerate;
	InUWPAccelerate=UWPAccelerate;
	InOutUWPAccelerate=UWPAccelerate;
	OutUWPAccelerate=UWPAccelerate;
	OutInUWPAccelerate=UWPAccelerate;
	InStandardProductive=StandardProductive;
	InStandardExpressive=StandardExpressive;
	InEntranceProductive=EntranceProductive;
	InEntranceExpressive=EntranceExpressive;
	InExitProductive=ExitProductive;
	InExitExpressive=ExitExpressive;
	OutStandardProductive=StandardProductive;
	OutStandardExpressive=StandardExpressive;
	OutEntranceProductive=EntranceProductive;
	OutEntranceExpressive=EntranceExpressive;
	OutExitProductive=ExitProductive;
	OutExitExpressive=ExitExpressive;
	InOutStandardProductive=StandardProductive;
	InOutStandardExpressive=StandardExpressive;
	InOutEntranceProductive=EntranceProductive;
	InOutEntranceExpressive=EntranceExpressive;
	InOutExitProductive=ExitProductive;
	InOutExitExpressive=ExitExpressive;
	OutInStandardProductive=StandardProductive;
	OutInStandardExpressive=StandardProductive;
	OutInEntranceProductive=EntranceProductive;
	OutInEntranceExpressive=EntranceExpressive;
	OutInExitProductive=ExitProductive;
	OutInExitExpressive=ExitExpressive;
	OutMozillaCurve=MozillaCurve;
	InMozillaCurve=MozillaCurve;
	InOutMozillaCurve=MozillaCurve;
	OutInMozillaCurve=MozillaCurve;
	InQuad=function(T)
		return T*T
	end;
	OutQuad=function(T)
		return T*(2-T)
	end;
	InOutQuad=function(T)
		if T<0.5 then
			return 2*T*T
		else
			return 2*(2-T)*T-1
		end
	end;
	OutInQuad=function(T)
		if T<0.5 then
			T*=2
			return T*(2-T)/2
		else
			T=T*2-1
			return T*T / 2+0.5
		end
	end;
	InCubic=function(T)
		return T*T*T
	end;
	OutCubic=function(T)
		T-=1
		return 1-T*T*T
	end;
	InOutCubic=function(T)
		if T<0.5 then
			return 4*T*T*T
		else
			T-=1
			return 1+4*T*T*T
		end
	end;
	OutInCubic=function(T)
		if T<0.5 then
			T=1-T*2
			return (1-T*T*T) / 2
		else
			T=T*2-1
			return T*T*T / 2+0.5
		end
	end;
	InQuart=function(T)
		return T*T*T*T
	end;
	OutQuart=function(T)
		T-=1
		return 1-T*T*T*T
	end;
	InOutQuart=function(T)
		if T<0.5 then
			T*=T
			return 8*T*T
		else
			T-=1
			return 1-8*T*T*T*T
		end
	end;
	OutInQuart=function(T)
		if T<0.5 then
			T=T*2-1
			return (1-T*T*T*T)/2
		else
			T=T*2-1
			return T*T*T*T / 2+0.5
		end
	end;
	InQuint=function(T)
		return T*T*T*T*T
	end;
	OutQuint=function(T)
		T-=1
		return T*T*T*T*T+1
	end;
	InOutQuint=function(T)
		if T<0.5 then
			return 16*T*T*T*T*T
		else
			T-=1
			return 16*T*T*T*T*T+1
		end
	end;
	OutInQuint=function(T)
		if T<0.5 then
			T=T*2-1
			return (T*T*T*T*T+1)/2
		else
			T=T*2-1
			return T*T*T*T*T / 2+0.5
		end
	end;
	InBack=function(T)
		return T*T*(3*T-2)
	end;
	OutBack=function(T)
		local TSubOne=T-1
		return TSubOne*TSubOne*(T*2+TSubOne)+1
	end;
	InOutBack=function(T)
		if T<0.5 then
			return 2*T*T*(2*3*T-2)
		else
			return 1+2*(T-1)*(T-1)*(2*3*T-2-2)
		end
	end;
	OutInBack=function(T)
		if T<0.5 then
			T*=2
			local TSubOne=T-1
			return (TSubOne*TSubOne*(T*2+TSubOne)+1)/2
		else
			T=T*2-1
			return T*T*(3*T-2)/2+0.5
		end
	end;
	InSine=function(T)
		return 1-cos(T*HALF_PI)
	end;
	OutSine=function(T)
		return sin(T*HALF_PI)
	end;
	InOutSine=function(T)
		return (1-cos(PI*T))/2
	end;
	OutInSine=function(T)
		if T<0.5 then
			return sin(T*PI)/2
		else
			return (1-cos((T*2-1)*HALF_PI))/2+0.5
		end
	end;
	OutBounce=OutBounce;
	InBounce=InBounce;
	InOutBounce=function(T)
		if T<0.5 then
			return InBounce(2*T)/2
		else
			return OutBounce(2*T-1)/2+0.5
		end
	end;
	OutInBounce=function(T)
		if T<0.5 then
			return OutBounce(2*T)/2
		else
			return InBounce(2*T-1)/2+0.5
		end
	end;
	InElastic=function(T)
		return exp((T*0.96380736418812-1)*8)*T*0.96380736418812*sin(4*T*0.96380736418812)*1.8752275007429
	end;
	OutElastic=function(T)
		return 1+(exp(8*(0.96380736418812-0.96380736418812*T-1))*0.96380736418812*(T-1)*sin(4*0.96380736418812*(1-T)))*1.8752275007429
	end;
	InOutElastic=function(T)
		if T<0.5 then
			return (exp(8*(2*0.96380736418812*T-1))*0.96380736418812*T*sin(7.71045891350496*T))*1.8752275007429
		else
			return 1+(exp(8*(0.96380736418812*(2-2*T)-1))*0.96380736418812*(T-1)*sin(3.85522945675248*(2-2*T)))*1.8752275007429
		end
	end;
	OutInElastic=function(T)
		if T<0.5 then
			T*=2
			return (1+(exp(8*(0.96380736418812-0.96380736418812*T-1))*0.96380736418812*(T-1)*sin(3.85522945675248*(1-T)))*1.8752275007429)/2
		else
			T=T*2-1
			return (exp((T*0.96380736418812-1)*8)*T*0.96380736418812*sin(4*T*0.96380736418812)*1.8752275007429)/2+0.5
		end
	end;
	InExpo=function(T)
		return T*T*exp(4*(T-1))
	end;
	OutExpo=function(T)
		return 1-(1-T)*(1-T)/exp(4*T)
	end;
	InOutExpo=function(T)
		if T<0.5 then
			return 2*T*T*exp(4*(2*T-1))
		else
			return 1-2*(T-1)*(T-1)*exp(4*(1-2*T))
		end
	end;
	OutInExpo=function(T)
		if T<0.5 then
			T*=2
			return (1-(1-T)*(1-T)/exp(4*T))/2
		else
			T=T*2-1
			return (T*T*exp(4*(T-1)))/2+0.5
		end
	end;
	InCirc=function(T)
		return -(sqrt(1-T*T)-1)
	end;
	OutCirc=function(T)
		T-=1
		return sqrt(1-T*T)
	end;
	InOutCirc=function(T)
		T*=2
		if T<1 then
			return -(sqrt(1-T*T)-1)/2
		else
			T-=2
			return (sqrt(1-T*T)-1)/2
		end
	end;
	OutInCirc=function(T)
		if T<0.5 then
			T=T*2-1
			return sqrt(1-T*T)/2
		else
			T=T*2-1
			return (-(sqrt(1-T*T)-1))/2+0.5
		end
	end;
},{
	__index=function(_,Index)
		error(tostring(Index).." is not a valid easing function.",2)
	end;
})

local TweenFunctions={
	FabricAccelerate={
		In=RawTweenFunctions.InFabricAccelerate;
		Out=RawTweenFunctions.OutFabricAccelerate;
		InOut=RawTweenFunctions.InOutFabricAccelerate;
		OutIn=RawTweenFunctions.OutInFabricAccelerate;
	};
	UWPAccelerate={
		In=RawTweenFunctions.InUWPAccelerate;
		Out=RawTweenFunctions.OutUWPAccelerate;
		InOut=RawTweenFunctions.InOutUWPAccelerate;
		OutIn=RawTweenFunctions.OutInUWPAccelerate;
	};
	Circ={
		In=RawTweenFunctions.InCirc;
		Out=RawTweenFunctions.OutCirc;
		InOut=RawTweenFunctions.InOutCirc;
		OutIn=RawTweenFunctions.OutInCirc;
	};
	RevBack={
		In=RawTweenFunctions.InRevBack;
		Out=RawTweenFunctions.OutRevBack;
		InOut=RawTweenFunctions.InOutRevBack;
		OutIn=RawTweenFunctions.OutInRevBack;
	};
	Spring={
		In=RawTweenFunctions.InSpring;
		Out=RawTweenFunctions.OutSpring;
		InOut=RawTweenFunctions.InOutSpring;
		OutIn=RawTweenFunctions.OutInSpring;
	};
	Standard={
		In=RawTweenFunctions.InStandard;
		Out=RawTweenFunctions.OutStandard;
		InOut=RawTweenFunctions.InOutStandard;
		OutIn=RawTweenFunctions.OutInStandard;
	};
	StandardExpressive={
		In=RawTweenFunctions.InStandardExpressive;
		Out=RawTweenFunctions.OutStandardExpressive;
		InOut=RawTweenFunctions.InOutStandardExpressive;
		OutIn=RawTweenFunctions.OutInStandardExpressive;
	};
	Linear={
		In=RawTweenFunctions.InLinear;
		Out=RawTweenFunctions.OutLinear;
		InOut=RawTweenFunctions.InOutLinear;
		OutIn=RawTweenFunctions.OutInLinear;
	};
	ExitProductive={
		In=RawTweenFunctions.InExitProductive;
		Out=RawTweenFunctions.OutExitProductive;
		InOut=RawTweenFunctions.InOutExitProductive;
		OutIn=RawTweenFunctions.OutInExitProductive;
	};
	Deceleration={
		In=RawTweenFunctions.InDeceleration;
		Out=RawTweenFunctions.OutDeceleration;
		InOut=RawTweenFunctions.InOutDeceleration;
		OutIn=RawTweenFunctions.OutInDeceleration;
	};
	Smoother={
		In=RawTweenFunctions.InSmoother;
		Out=RawTweenFunctions.OutSmoother;
		InOut=RawTweenFunctions.InOutSmoother;
		OutIn=RawTweenFunctions.OutInSmoother;
	};
	FabricStandard={
		In=RawTweenFunctions.InFabricStandard;
		Out=RawTweenFunctions.OutFabricStandard;
		InOut=RawTweenFunctions.InOutFabricStandard;
		OutIn=RawTweenFunctions.OutInFabricStandard;
	};
	RidiculousWiggle={
		In=RawTweenFunctions.InRidiculousWiggle;
		Out=RawTweenFunctions.OutRidiculousWiggle;
		InOut=RawTweenFunctions.InOutRidiculousWiggle;
		OutIn=RawTweenFunctions.OutInRidiculousWiggle;
	};
	MozillaCurve={
		In=RawTweenFunctions.InMozillaCurve;
		Out=RawTweenFunctions.OutMozillaCurve;
		InOut=RawTweenFunctions.InOutMozillaCurve;
		OutIn=RawTweenFunctions.OutInMozillaCurve;
	};
	Expo={
		In=RawTweenFunctions.InExpo;
		Out=RawTweenFunctions.OutExpo;
		InOut=RawTweenFunctions.InOutExpo;
		OutIn=RawTweenFunctions.OutInExpo;
	};
	Sine={
		In=RawTweenFunctions.InSine;
		Out=RawTweenFunctions.OutSine;
		InOut=RawTweenFunctions.InOutSine;
		OutIn=RawTweenFunctions.OutInSine;
	};
	Cubic={
		In=RawTweenFunctions.InCubic;
		Out=RawTweenFunctions.OutCubic;
		InOut=RawTweenFunctions.InOutCubic;
		OutIn=RawTweenFunctions.OutInCubic;
	};
	EntranceExpressive={
		In=RawTweenFunctions.InEntranceExpressive;
		Out=RawTweenFunctions.OutEntranceExpressive;
		InOut=RawTweenFunctions.InOutEntranceExpressive;
		OutIn=RawTweenFunctions.OutInEntranceExpressive;
	};
	Elastic={
		In=RawTweenFunctions.InElastic;
		Out=RawTweenFunctions.OutElastic;
		InOut=RawTweenFunctions.InOutElastic;
		OutIn=RawTweenFunctions.OutInElastic;
	};
	Quint={
		In=RawTweenFunctions.InQuint;
		Out=RawTweenFunctions.OutQuint;
		InOut=RawTweenFunctions.InOutQuint;
		OutIn=RawTweenFunctions.OutInQuint;
	};
	EntranceProductive={
		In=RawTweenFunctions.InEntranceProductive;
		Out=RawTweenFunctions.OutEntranceProductive;
		InOut=RawTweenFunctions.InOutEntranceProductive;
		OutIn=RawTweenFunctions.OutInEntranceProductive;
	};
	Bounce={
		In=RawTweenFunctions.InBounce;
		Out=RawTweenFunctions.OutBounce;
		InOut=RawTweenFunctions.InOutBounce;
		OutIn=RawTweenFunctions.OutInBounce;
	};
	Smooth={
		In=RawTweenFunctions.InSmooth;
		Out=RawTweenFunctions.OutSmooth;
		InOut=RawTweenFunctions.InOutSmooth;
		OutIn=RawTweenFunctions.OutInSmooth;
	};
	Back={
		In=RawTweenFunctions.InBack;
		Out=RawTweenFunctions.OutBack;
		InOut=RawTweenFunctions.InOutBack;
		OutIn=RawTweenFunctions.OutInBack;
	};
	Quart={
		In=RawTweenFunctions.InQuart;
		Out=RawTweenFunctions.OutQuart;
		InOut=RawTweenFunctions.InOutQuart;
		OutIn=RawTweenFunctions.OutInQuart;
	};
	StandardProductive={
		In=RawTweenFunctions.InStandardProductive;
		Out=RawTweenFunctions.OutStandardProductive;
		InOut=RawTweenFunctions.InOutStandardProductive;
		OutIn=RawTweenFunctions.OutInStandardProductive;
	};
	Quad={
		In=RawTweenFunctions.InQuad;
		Out=RawTweenFunctions.OutQuad;
		InOut=RawTweenFunctions.InOutQuad;
		OutIn=RawTweenFunctions.OutInQuad;
	};
	FabricDecelerate={
		In=RawTweenFunctions.InFabricDecelerate;
		Out=RawTweenFunctions.OutFabricDecelerate;
		InOut=RawTweenFunctions.InOutFabricDecelerate;
		OutIn=RawTweenFunctions.OutInFabricDecelerate;
	};
	Acceleration={
		In=RawTweenFunctions.InAcceleration;
		Out=RawTweenFunctions.OutAcceleration;
		InOut=RawTweenFunctions.InOutAcceleration;
		OutIn=RawTweenFunctions.OutInAcceleration;
	};
	SoftSpring={
		In=RawTweenFunctions.InSoftSpring;
		Out=RawTweenFunctions.OutSoftSpring;
		InOut=RawTweenFunctions.InOutSoftSpring;
		OutIn=RawTweenFunctions.OutInSoftSpring;
	};
	ExitExpressive={
		In=RawTweenFunctions.InExitExpressive;
		Out=RawTweenFunctions.OutExitExpressive;
		InOut=RawTweenFunctions.InOutExitExpressive;
		OutIn=RawTweenFunctions.OutInExitExpressive;
	};
	Sharp={
		In=RawTweenFunctions.InSharp;
		Out=RawTweenFunctions.OutSharp;
		InOut=RawTweenFunctions.InOutSharp;
		OutIn=RawTweenFunctions.OutInSharp;
	};
}

local SWait=function(Seconds)
	Seconds=max(Seconds or 0.03,0)
	local TimeRemaining=Seconds
	while TimeRemaining>0 do
		TimeRemaining-=Wait(Heartbeat)
	end
	return Seconds-TimeRemaining
end

Boat.Create=function(self,Object,Data)
	if not Object or typeof(Object)~="Instance" then
		return warn("Invalid object to tween:",Object)
	end
	Data=typeof(Data)=="table" and Data or {}
	local TweenFunction=TweenFunctions[Data.EasingStyle or "Quad"][Data.EasingDirection or "In"]
	local Time=max(typeof(Data.Time)=="number" and Data.Time or 1,0.001)
	local Goal=typeof(Data.Goal)=="table" and Data.Goal or {}
	local DelayTime=typeof(Data.DelayTime)=="number" and Data.DelayTime>0.027 and Data.DelayTime
	local RepeatCount=(typeof(Data.RepeatCount)=="number" and max(Data.RepeatCount,-1) or 0)+1
	local TweenData={}
	for Property,EndValue in next,Goal do
		TweenData[Property]=TypeLerpers[typeof(EndValue)](Object[Property],EndValue)
	end
	local CompletedEvent=NewSignal()
	local StoppedEvent=NewSignal()
	local ResumedEvent=NewSignal()
	local PlayedEvent=NewSignal()
	local PlaybackConnection
	local StartTime,ElapsedTime=osclock(),0
	local TweenObject={
		Instance=Object;
		PlaybackState="Begin";
		Completed=CompletedEvent;
		Resumed=ResumedEvent;
		Stopped=StoppedEvent;
		Played=PlayedEvent
	}
	TweenObject.Destroy=function(self)
		if PlaybackConnection then
			Disconnect(PlaybackConnection)
			PlaybackConnection=nil
		end
		CompletedEvent:DisconnectAll()
		StoppedEvent:DisconnectAll()
		ResumedEvent:DisconnectAll()
		PlayedEvent:DisconnectAll()
		TweenObject=nil
	end
	local CurrentlyReversing=false
	local CurrentLayer=0
	local Play
	Play=function(Layer,Reverse)
		if PlaybackConnection then
			Disconnect(PlaybackConnection)
			PlaybackConnection=nil
		end
		Layer=Layer or 1
		if RepeatCount~=0 then
			if Layer>RepeatCount then
				TweenObject.PlaybackState="Completed"
				CompletedEvent:Fire()
				CurrentlyReversing=false
				CurrentLayer=1
				return
			end
		end
		CurrentLayer=Layer
		if Reverse then
			CurrentlyReversing=true
		end
		if DelayTime then
			TweenObject.PlaybackState="Delayed";
			(DelayTime<2 and SWait or twait)(DelayTime)
		end
		StartTime=osclock()-ElapsedTime
		PlaybackConnection=Connect(Heartbeat,function()
			ElapsedTime=osclock()-StartTime
			if ElapsedTime>=Time then
				if Reverse then
					for Property,Lerper in next,TweenData do
						Object[Property]=Lerper(0)
					end
				else
					for Property,Lerper in next,TweenData do
						Object[Property]=Lerper(1)
					end
				end
				Disconnect(PlaybackConnection)
				PlaybackConnection=nil
				if Reverse then
					ElapsedTime=0
					Play(Layer+1,false)
				else
					if Data.Reverses then
						ElapsedTime=0
						Play(Layer,true)
					else
						ElapsedTime=0
						Play(Layer+1,false)
					end
				end
			else
				local Delta=Reverse and (1-ElapsedTime/Time) or (ElapsedTime/Time)
				local Position=clamp(TweenFunction(Delta),0,1)
				for Property,Lerper in next,TweenData do
					Object[Property]=Lerper(Position)
				end
			end
		end)
		TweenObject.PlaybackState="Playing"
	end
	TweenObject.Play=function(self)
		PlayedEvent:Fire()
		ElapsedTime=0
		Play(1,false)
	end
	TweenObject.Stop=function(self)
		if PlaybackConnection then
			PlaybackConnection:Disconnect()
			PlaybackConnection=nil
			TweenObject.PlaybackState="Cancelled"
			StoppedEvent:Fire()
		end
	end
	TweenObject.Resume=function(self)
		Play(CurrentLayer,CurrentlyReversing)
		ResumedEvent:Fire()
	end
	return TweenObject
end
BasicFunctions.TweenCreate=Boat.Create

--[==[
	Main
]==]
BasicFunctions.AddDebris=function(Object,DestroyTime)
	DestroyTime=osclock()+DestroyTime
	while osclock()<=DestroyTime do
		Wait(Heartbeat)
	end
	if Object then
		Destroy(Object)
	end
end
BasicFunctions.TorusRandom=function(R,Y,r)
	local theta=mrandom()*2*3.141592653589793
	local phi=mrandom()*2*3.141592653589793
	local x=(R+r*cos(phi))*cos(theta)
	local y=Y or r*sin(phi)
	local z=(R+r*cos(phi))*sin(theta)
	return x,y,z
end

local Effects={}
Effects.__index=Effects
local Settings={
	Container=nil,
	EffectList={},
	EffectLimit=500
}
Effects._destroyall=false
Effects._instances={}
Effects._reuseables={}
Effects._visualcount=0

local MainMaid=Maid.new()

local LerpTypes=setmetatable({
	number=Lerp,
	Color3=Color3LerpFunction,
	Vector3=vlerp,
	CFrame=function(V0,V1,Alpha)
		return V0:Lerp(V1,Alpha)
	end,
	Vector2=function(V0,V1,Alpha)
		return V0:Lerp(V1,Alpha)
	end,
	UDim2=function(V0,V1,Alpha)
		return V0:Lerp(V1,Alpha)
	end
},{})

local QuadraticBezier=function(a,b,c,t)
	local Lerp=LerpTypes[typeof(a)]
	if Lerp then
		local P1=Lerp(a,b,t)
		local P2=Lerp(b,c,t)
		local Calculated=Lerp(P1,P2,t)
		return Calculated
	end
end

Effects.SetSetting=function(self,Name,Value)
	assert(typeof(Name)=="string","Failed to set Setting,name is not a string type!")
	Settings[Name]=Value
end

Effects.AddToList=function(self,instance)
	tclear(Effects._reuseables)
	for _,v in next,GetChildren(instance) do
		Effects._reuseables[v.Name]=v
		MainMaid:GiveTask(v)
	end
end

Effects.Destroy=function(self)
	if not Effects._destroyall then
		MainMaid:DoCleaning()
		Effects._destroyall=true
	else
		warn("Already destroyed")
	end
end

Effects.LightningStrike=function(self,Color,Size,Start,End,Offset,Segments,Alpha)
	if self.__destroyall then return end
	if Effects._visualcount >= Settings.EffectLimit then return end
	local Model=new("Model")
	local Points={}
	local Maid=Maid.new()
	Maid:GiveTask(Model)
	Effects._visualcount+=1
	for i=0,Segments do
		if i==0 then
			local Position=LerpTypes.Vector3(Start,End,i/Segments)
			tinsert(Points,Position)
		elseif i<Segments then
			local Off=Vector3.new(rand(-Offset*100,Offset*100)/100,rand(-Offset*100,Offset*100)/100,rand(-Offset*100,Offset*100)/100)
			local Position=LerpTypes.Vector3(Start,End,i/Segments)
			tinsert(Points,Position+Off)
		else
			local Position=LerpTypes.Vector3(Start,End,1)
			tinsert(Points,Position)
		end
	end
	Model.Parent=Settings.Container
	for i,v in next,Points do
		local Point=v
		local NextPoint=Points[i+1]
		if NextPoint then
			local NextPoint=NextPoint
			local Part=new("Part",Model)
			local StartSizeStartTransparency=Part.Size,1
			local EndSize,EndTransparency=v3(Size,Size,v3m(Point-NextPoint)),0
			local Elapse=0
			local StartTime=osclock()
			Part.Material=enum.Material.Neon;Part.Color=Color;Part.Size=v3(0,0,vmagnitude(Point-NextPoint));Part.CFrame=cfl((Point+NextPoint)/2,NextPoint);Part.Transparency=1;Part.CanCollide=false;Part.CanQuery=false;Part.CanTouch=false;Part.AudioCanCollide=false;Part.Anchored=true;Part.Massless=true;Part.CastShadow=false
			Maid:GiveTask(Heartbeat:Connect(function()
				local DeltaTime=osclock()-StartTime
				Elapse=DeltaTime/Alpha
				if Elapse<=1 then
					local Size=LerpTypes.Vector3(StartSize,EndSize,Elapse)
					local Transparency=LerpTypes.number(StartTransparency,EndTransparency,Elapse)
					Part.Size=Size
					Part.Transparency=Transparency
				elseif Elapse>1 and Elapse<=2 then
					local Elapse=2-Elapse
					local Size=LerpTypes.Vector3(StartSize,EndSize,Elapse)
					local Transparency=LerpTypes.number(StartTransparency,EndTransparency,Elapse)
					Part.Size=Size
					Part.Transparency=Transparency
				end
			end))
		end
	end
	defer(function()
		local StopTime=osclock()+Alpha*2
		while osclock()<=StopTime do
			Heartbeat:Wait()
		end
		Maid:DoCleaning()
		Effects._visualcount-=1
	end)
	return Points[Segments+1]
end

Effects.WackyEffect=function(self,EffectName,Alpha,Reverse,Material,Reflectance,Size,EndSize,Coordinate,EndCoordinate,Color,EndColor,Transparency,EndTransparency)
	if self.__destroyall or Effects._visualcount>=Settings.EffectLimit then return end
	local EffectPart
	if sfind(EffectName,"/") then
		local t=ssplit(EffectName,"/")
		EffectPart=Effects._reuseables[t[1]][t[2]]
	else
		EffectPart=Effects._reuseables[EffectName]
	end
	if EffectPart then
		EffectPart=Clone(EffectPart)
		local EffectMaid=Maid.new()
		EffectMaid:GiveTask(EffectPart)
		Alpha=Alpha or 0.2
		Reverse=Reverse or false
		Material=enum.Material[Material] or enum.Material.Neon
		Reflectance=Reflectance or 0
		Size=Size or v3_0
		EndSize=EndSize or Size
		Coordinate=Coordinate or cf_0
		EndCoordinate=EndCoordinate or Coordinate
		Color=Color or BLACK_COLOR3
		EndColor=EndColor or Color
		Transparency=Transparency or 0
		EndTransparency=EndTransparency or Transparency
		Effects._visualcount+=1
		local Elapse=0
		local StartTime=osclock()
		local SpecialMesh=FindFirstChildOfClass(EffectPart,"SpecialMesh")
		if IsA(EffectPart,"BasePart") then
			if SpecialMesh then
				EffectPart.Size=v3(1,1,1);EffectPart.Material=Material;EffectPart.Reflectance=Reflectance;EffectPart.CFrame=Coordinate;EffectPart.Color=Color;EffectPart.Transparency=Transparency;EffectPart.Parent=Settings.Container
				SpecialMesh.Scale=Size
				EffectMaid:GiveTask(Heartbeat:Connect(function()
					local DeltaTime=osclock()-StartTime
					Elapse=DeltaTime/Alpha
					if Reverse then
						if Elapse<=1 then
							local Size=LerpTypes.Vector3(Size,EndSize,Elapse)
							local CFrame=LerpTypes.CFrame(Coordinate,EndCoordinate,Elapse)
							local Color=LerpTypes.Color3(Color,EndColor,Elapse)
							local Transparency=LerpTypes.number(Transparency,EndTransparency,Elapse)
							EffectPart.CFrame=CFrame;EffectPart.Color=Color;EffectPart.Transparency=Transparency
							SpecialMesh.Scale=Size
						elseif Elapse>1 and Elapse<2 then
							local Elapse=2-DeltaTime/Alpha
							local Size=LerpTypes.Vector3(Size,EndSize,Elapse)
							local CFrame=LerpTypes.CFrame(Coordinate,EndCoordinate,Elapse)
							local Color=LerpTypes.Color3(Color,EndColor,Elapse)
							local Transparency=LerpTypes.number(Transparency,EndTransparency,Elapse)
							EffectPart.CFrame=CFrame;EffectPart.Color=Color;EffectPart.Transparency=Transparency
							SpecialMesh.Scale=Size
						else
							EffectMaid:DoCleaning()
							Effects._visualcount-=1
						end
					else
						if Elapse<1 then
							local Size=LerpTypes.Vector3(Size,EndSize,Elapse)
							local CFrame=LerpTypes.CFrame(Coordinate,EndCoordinate,Elapse)
							local Color=LerpTypes.Color3(Color,EndColor,Elapse)
							local Transparency=LerpTypes.number(Transparency,EndTransparency,Elapse)
							EffectPart.CFrame=CFrame;EffectPart.Color=Color;EffectPart.Transparency=Transparency
							SpecialMesh.Scale=Size
						else
							EffectMaid:DoCleaning()
							Effects._visualcount-=1
						end
					end
				end))
			else
				EffectPart.Material=Material;EffectPart.Reflectance=Reflectance;EffectPart.Size=Size;EffectPart.CFrame=Coordinate;EffectPart.Color=Color;EffectPart.Transparency=Transparency;EffectPart.CanCollide=false;EffectPart.CanQuery=false;EffectPart.CanTouch=false;EffectPart.AudioCanCollide=false;EffectPart.Anchored=true;EffectPart.Massless=true;EffectPart.CastShadow=false;EffectPart.Parent=Settings.Container
				EffectMaid:GiveTask(Connect(Heartbeat,function()
					local delta=osclock()-StartTime
					Elapse=delta/Alpha
					if Reverse then
						if Elapse<=1 then
							local Size=LerpTypes.Vector3(Size,EndSize,Elapse)
							local CFrame=LerpTypes.CFrame(Coordinate,EndCoordinate,Elapse)
							local Color=LerpTypes.Color3(Color,EndColor,Elapse)
							local Transparency=LerpTypes.number(Transparency,EndTransparency,Elapse)
							EffectPart.Size=Size;EffectPart.CFrame=CFrame;EffectPart.Color=Color;EffectPart.Transparency=Transparency
						elseif Elapse>1 and Elapse<2 then
							Elapse=2-DeltaTime/Alpha
							local Size=LerpTypes.Vector3(Size,EndSize,Elapse)
							local CFrame=LerpTypes.CFrame(Coordinate,EndCoordinate,Elapse)
							local Color=LerpTypes.Color3(Color,EndColor,Elapse)
							local Transparency=LerpTypes.number(Transparency,EndTransparency,Elapse)
							EffectPart.Size=Size;EffectPart.CFrame=CFrame;EffectPart.Color=Color;EffectPart.Transparency=Transparency
						else
							EffectMaid:DoCleaning()
							Effects._visualcount-=1
						end
					else
						if Elapse<1 then
							local Size=LerpTypes.Vector3(Size,EndSize,Elapse)
							local CFrame=LerpTypes.CFrame(Coordinate,EndCoordinate,Elapse)
							local Color=LerpTypes.Color3(Color,EndColor,Elapse)
							local Transparency=LerpTypes.number(Transparency,EndTransparency,Elapse)
							EffectPart.Size=Size;EffectPart.CFrame=CFrame;EffectPart.Color=Color;EffectPart.Transparency=Transparency
						else
							EffectMaid:DoCleaning()
							Effects._visualcount-=1
						end
					end
				end))
			end
		end
	end
end
Effects.CurveEffect=function(self,EffectName,Alpha,Reverse,Material,Reflectance,Size,EndSize,Coordinate,EndCoordinate,Color,EndColor,Transparency,EndTransparency)
	if self.__destroyall or Effects._visualcount>=Settings.EffectLimit then return end
	local EffectPart
	if sfind(EffectName,"/") then
		local t=ssplit(EffectName,"/")
		EffectPart=Effects._reuseables[t[1]][t[2]]
	else
		EffectPart=Effects._reuseables[EffectName]
	end
	if EffectPart then
		EffectPart=Clone(EffectPart)
		local EffectMaid=Maid.new()
		EffectMaid:GiveTask(EffectPart)
		Alpha=Alpha or 0.2
		Reverse=Reverse or false
		Material=Material or Enum.Material.Neon
		Reflectance=Reflectance or 0
		SizePointA=SizePointA or v3_0
		SizePointB=SizePointB or SizePointB
		SizePointC=SizePointC or SizePointB
		ColorPointA=ColorPointA or BLACK_COLOR3
		ColorPointB=ColorPointB or ColorPointA
		ColorPointC=ColorPointC or ColorPointA
		TransparencyPointA=TransparencyPointA or 1
		TransparencyPointB=TransparencyPointB or 0
		TransparencyPointC=TransparencyPointC or 1
		CFramePointA=CFramePointA or cf_0
		CFramePointB=CFramePointB or CFramePointA
		CFramePointC=CFramePointC or CFramePointA
		Effects._visualcount+=1
		local Elapse=0
		local StartTime=osclock()
		local SpecialMesh=FindFirstChildOfClass(EffectPart,"SpecialMesh")
		if IsA(EffectPart,"BasePart") then
			if SpecialMesh then
				EffectPart.Size=v3(1,1,1);EffectPart.Material=Material;EffectPart.Reflectance=Reflectance;EffectPart.CFrame=Coordinate;EffectPart.Color=Color;EffectPart.Transparency=Transparency;EffectPart.Parent=Settings.Container
				SpecialMesh.Scale=Size
				EffectMaid:GiveTask(Heartbeat:Connect(function()
					local DeltaTime=osclock()-StartTime
					Elapse=DeltaTime/Alpha
					if Reverse then
						if Elapse<=1 then
							local Size=QuadraticBezier(SizePointA,SizePointB,SizePointC,Elapse)
							local CFrame=QuadraticBezier(CFramePointA,CFramePointB,CFramePointC,Elapse)
							local Color=QuadraticBezier(ColorPointA,ColorPointB,ColorPointC,Elapse)
							local Transparency=QuadraticBezier(TransparencyPointA,TransparencyPointB,TransparencyPointC,Elapse)
							EffectPart.CFrame=CFrame;EffectPart.Color=Color;EffectPart.Transparency=Transparency
							SpecialMesh.Scale=Size
						elseif Elapse>1 and Elapse<2 then
							local Elapse=2-DeltaTime/Alpha
							local Size=QuadraticBezier(SizePointA,SizePointB,SizePointC,Elapse)
							local CFrame=QuadraticBezier(CFramePointA,CFramePointB,CFramePointC,Elapse)
							local Color=QuadraticBezier(ColorPointA,ColorPointB,ColorPointC,Elapse)
							local Transparency=QuadraticBezier(TransparencyPointA,TransparencyPointB,TransparencyPointC,Elapse)
							EffectPart.CFrame=CFrame;EffectPart.Color=Color;EffectPart.Transparency=Transparency
							SpecialMesh.Scale=Size
						else
							EffectMaid:DoCleaning()
							Effects._visualcount-=1
						end
					else
						if Elapse<1 then
							local Size=QuadraticBezier(SizePointA,SizePointB,SizePointC,Elapse)
							local CFrame=QuadraticBezier(CFramePointA,CFramePointB,CFramePointC,Elapse)
							local Color=QuadraticBezier(ColorPointA,ColorPointB,ColorPointC,Elapse)
							local Transparency=QuadraticBezier(TransparencyPointA,TransparencyPointB,TransparencyPointC,Elapse)
							EffectPart.CFrame=CFrame;EffectPart.Color=Color;EffectPart.Transparency=Transparency
							SpecialMesh.Scale=Size
						else
							EffectMaid:DoCleaning()
							Effects._visualcount-=1
						end
					end
				end))
			else
				EffectPart.Material=Material;EffectPart.Reflectance=Reflectance;EffectPart.Size=Size;EffectPart.CFrame=Coordinate;EffectPart.Color=Color;EffectPart.Transparency=Transparency;EffectPart.CanCollide=false;EffectPart.CanQuery=false;EffectPart.CanTouch=false;EffectPart.AudioCanCollide=false;EffectPart.Anchored=true;EffectPart.Massless=true;EffectPart.CastShadow=false;EffectPart.Parent=Settings.Container
				EffectMaid:GiveTask(Connect(Heartbeat,function()
					local delta=osclock()-StartTime
					Elapse=delta/Alpha
					if Reverse then
						if Elapse<=1 then
							local Size=QuadraticBezier(SizePointA,SizePointB,SizePointC,Elapse)
							local CFrame=QuadraticBezier(CFramePointA,CFramePointB,CFramePointC,Elapse)
							local Color=QuadraticBezier(ColorPointA,ColorPointB,ColorPointC,Elapse)
							local Transparency=QuadraticBezier(TransparencyPointA,TransparencyPointB,TransparencyPointC,Elapse)
							EffectPart.Size=Size;EffectPart.CFrame=CFrame;EffectPart.Color=Color;EffectPart.Transparency=Transparency
						elseif Elapse>1 and Elapse<2 then
							Elapse=2-DeltaTime/Alpha
							local Size=QuadraticBezier(SizePointA,SizePointB,SizePointC,Elapse)
							local CFrame=QuadraticBezier(CFramePointA,CFramePointB,CFramePointC,Elapse)
							local Color=QuadraticBezier(ColorPointA,ColorPointB,ColorPointC,Elapse)
							local Transparency=QuadraticBezier(TransparencyPointA,TransparencyPointB,TransparencyPointC,Elapse)
							EffectPart.Size=Size;EffectPart.CFrame=CFrame;EffectPart.Color=Color;EffectPart.Transparency=Transparency
						else
							EffectMaid:DoCleaning()
							Effects._visualcount-=1
						end
					else
						if Elapse<1 then
							local Size=QuadraticBezier(SizePointA,SizePointB,SizePointC,Elapse)
							local CFrame=QuadraticBezier(CFramePointA,CFramePointB,CFramePointC,Elapse)
							local Color=QuadraticBezier(ColorPointA,ColorPointB,ColorPointC,Elapse)
							local Transparency=QuadraticBezier(TransparencyPointA,TransparencyPointB,TransparencyPointC,Elapse)
							EffectPart.Size=Size;EffectPart.CFrame=CFrame;EffectPart.Color=Color;EffectPart.Transparency=Transparency
						else
							EffectMaid:DoCleaning()
							Effects._visualcount-=1
						end
					end
				end))
			end
		end
	end
end
Effects.TweenEffect=function(self,EffectName,Material,Reflectance,Size,Coordinate,Color,Transparency,TweenTime,PropEasing,PropDirection,Reverse,PropTable,EndTransparency,TransparencyEasing,TransparencyDirection)
	if self.__destroyall or Effects._visualcount>=Settings.EffectLimit then return end
	local EffectPart
	if sfind(EffectName,"/") then
		local t=ssplit(EffectName,"/")
		EffectPart=Effects._reuseables[t[1]][t[2]]
	else
		EffectPart=Effects._reuseables[EffectName]
	end
	if EffectPart then
		EffectPart=Clone(EffectPart)
		local EffectMaid=Maid.new()
		EffectMaid:GiveTask(EffectPart)
		Material=enum.Material[Material] or enum.Material.Neon
		Reflectance=Reflectance or 0
		Size=Size or v3_0
		Coordinate=Coordinate or cf_0
		Color=Color or BLACK_COLOR3
		Transparency=Transparency or 0
		TweenTime=TweenTime or 0.2
		PropEasing=PropEasing or "Linear"
		PropDirection=PropDirection or "In"
		Reverse=Reverse or false
		PropTable=PropTable or {}
		EndTransparency=EndTransparency or Transparency
		TransparencyEasing=TransparencyEasing or "Linear"
		TransparencyDirection=TransparencyDirection or "In"
		Effects._visualcount+=1
		local Elapse=0
		local StartTime=osclock()
		local SpecialMesh=FindFirstChildOfClass(EffectPart,"SpecialMesh")
		if IsA(EffectPart,"BasePart") then
			if SpecialMesh then
				EffectPart.Size=v3(1,1,1);EffectPart.Material=Material;EffectPart.Reflectance=Reflectance;EffectPart.CFrame=Coordinate;EffectPart.Color=Color;EffectPart.Transparency=Transparency;EffectPart.Parent=Settings.Container
				SpecialMesh.Scale=Size
				local TweenObject=Boat:Create(EffectPart,{Time=TweenTime,EasingStyle=PropEasing,EasingDirection=PropDirection,Reverse=Reverse,Goal=PropTable})
				local MeshObject=BoatTween:Create(SpecialMesh,{Time=TweenTime,EasingStyle=PropEasing,EasingDirection=PropDirection,Reverse=Reverse,Goal={Scale=PropTable.Size}})
				local TransparencyObject=Boat:Create(EffectPart,{Time=TweenTime,EasingStyle=TransparencyEasing,EasingDirection=TransparencyDirection,Reverse=Reverse,Goal={Transparency=EndTransparency}})
				TweenObject:Play()
				TransparencyObject:Play()
				EffectMaid:GiveTask(TweenObject)
				EffectMaid:GiveTask(MeshObject)
				EffectMaid:GiveTask(TransparencyObject)
				TweenObject.Completed:Once(function()
					EffectMaid:DoCleaning()
					Effects._visualcount-=1
				end)
			else
				EffectPart.Material=Material;EffectPart.Reflectance=Reflectance;EffectPart.Size=Size;EffectPart.CFrame=Coordinate;EffectPart.Color=Color;EffectPart.Transparency=Transparency;EffectPart.CanCollide=false;EffectPart.CanQuery=false;EffectPart.CanTouch=false;EffectPart.AudioCanCollide=false;EffectPart.Anchored=true;EffectPart.Massless=true;EffectPart.CastShadow=false;EffectPart.Parent=Settings.Container
				local TweenObject=Boat:Create(EffectPart,{Time=TweenTime,EasingStyle=PropEasing,EasingDirection=PropDirection,Reverse=Reverse,Goal=PropTable})
				local TransparencyObject=Boat:Create(EffectPart,{Time=TweenTime,EasingStyle=TransparencyEasing,EasingDirection=TransparencyDirection,Reverse=Reverse,Goal={Transparency=EndTransparency}})
				TweenObject:Play()
				TransparencyObject:Play()
				EffectMaid:GiveTask(TweenObject)
				EffectMaid:GiveTask(TransparencyObject)
				TweenObject.Completed:Once(function()
					EffectMaid:DoCleaning()
					Effects._visualcount-=1
				end)
			end
		end
	end
end
BasicFunctions.Effects=Effects

return BasicFunctions
