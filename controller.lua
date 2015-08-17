-- Put your global variables here
avoid_obstacle = false

isG = 0
isL = 0
robotType = ""

isTurning = 0
isMovingTowardRoom = 0
randomWander = 0
inRoom = 0
inCentralRoom = false
MAX_ROOM_WANDER_STEPS = 20
MAX_CENTRAL_ROOM_WANDER_STEPS = 50
roomWanderSteps = 0
leaveRoom = false
stetpsUntilLeave = 0

closestRoom = -1
roomNumber = -1

isMovingTowardLight = 0
saveLightValue = 0

roomQuality = 0
roomMissingAttribute = 0
roomSpecialAttribute = 0
roomObjects = 0
bestRoomQuality = 0

stepsInRoom = 0
STEPS_UNTIL_QUALITY = 150
STEPS_UNTIL_PROBABILITY = 100


--[[ This function is executed every time you press the 'execute'
     button ]]
function init()
	i = string.find(robot.id, "fbG")
	if i ~= nil then
		-- Robot is of type G(round)
		isG = 1
		robotType = "fbG"
		robot.leds.set_single_color(13, "yellow")
	else
		-- Robot is of type L(ight)
		isL = 1
		robotType = "fbL"
		robot.leds.set_single_color(13, "cyan")
	end

	isMovingTowardRoom = 1
	inCentralRoom = true

end



--[[ This function is executed at each time step
     It must contain the logic of your controller ]]
function step()
	robot.colored_blob_omnidirectional_camera.enable() -- maybe move this to init()

	closestRoom = 0
	closestRoomAngle = 0
	closestRoomDistance = 255

	-- -------------------------------
	-- 			SENSE
	-- -------------------------------

	-- Obstacle avoidance (obstacleAvoidance_sta.lua)
	obstacle = false
	for i=1,4 do
		if (robot.proximity[i].value > 0.2) then
			obstacle = true
			break
		end
	end
	if (not obstacle) then
		for i=20,24 do
			if (robot.proximity[i].value > 0.2) then
				obstacle = true
				break
			end
		end
	end
	-- Obstacle avoidance [end]

	robotsInSameRoom = countRobotsInSameRoom()


	closestRoom, closestRoomDistance, closestRoomAngle = findClosestRoom()

	-- -------------------------------
	-- 			THINK
	-- -------------------------------

	-- Obstacle avoidance (obstacleAvoidance_sta.lua)
	if(not avoid_obstacle) then
		if(obstacle) then
			avoid_obstacle = true
			turning_steps = robot.random.uniform_int(4,30)
			turning_right = robot.random.bernoulli()
		end
	else
		turning_steps = turning_steps - 1
		if(turning_steps == 0) then 
			avoid_obstacle = false
		end
	end
	-- Obstacle avoidance [end]



	-- -------------------------------
	-- 			ACT
	-- -------------------------------

	if isMovingTowardRoom == 1 then
		-- Turn toward closest room

		--  /^\
		-- /_!_\ The angles go from 0 to pi and then -pi to 0, not 0 to 2*pi
		-- like any sane person would suppose.
		-- Thanks for the documentation that does not say a word about that.
		if (closestRoomAngle > 0.2) then
			-- The room is on the left
			robot.wheels.set_velocity(-5, 5)
			isTurning = 1
		elseif (closestRoomAngle < -0.2) then
			--The room is on the right
			robot.wheels.set_velocity(5, -5)
			isTurning = 1
		else
			-- When inside error margin, stop turning.
			isTurning = 0
		end

		-- Move toward the room
		if isTurning == 0 then
			robot.wheels.set_velocity(5, 5)
		end

		if closestRoomDistance < 10 then
			-- Final approach
			isMovingTowardRoom = 0
			randomWander = 1
		end

	end -- if isMovingTowardRoom == 1 then

	if randomWander == 1 then
		robot.wheels.set_velocity(5, 5)
		if roomWanderSteps == MAX_ROOM_WANDER_STEPS then
			if inCentralRoom then
				inRoom = 1
				inCentralRoom = false
			elseif inRoom == 1 then
				inRoom = 0
				inCentralRoom = true
			end
			stepsInRoom = 0
			roomNumber = closestRoom
			roomWanderSteps = roomWanderSteps + 1
		else
			roomWanderSteps = roomWanderSteps + 1
		end

		if inRoom == 1 then
			stepsInRoom = stepsInRoom + 1
			roomQuality, roomMissingAttribute = getInfo(robotType)
			roomObjects = objectQuality()
			if roomSpecialAttribute == 0 then
				-- Not computed yet.
				roomSpecialAttribute = getSpecialAttribute(robotType)
			end
			if roomMissingAttribute ~= 0 and roomSpecialAttribute ~= 0 and roomQuality == 0 then
				-- We got the missing attribute from another robot, but we still need
				-- to calculate the quality of the room.
				-- We suppose a room quality of '0' is impossible, thus meaning an
				-- unset quality.
				roomQuality = (roomObjects + roomSpecialAttribute + roomMissingAttribute)/3
			end
			broadcastQualities(robotType, roomQuality, roomSpecialAttribute, roomNumber)
			log("["..roomNumber.."_"..robot.id.."] Qual: "..roomQuality..", obj: "..roomObjects..", spe: "..roomSpecialAttribute..", miss: "..roomMissingAttribute)


			if roomQuality >= bestRoomQuality then
				bestRoomQuality = roomQuality
			else
				-- Lesser quality room, do not waste more time in here.
				leaveRoom = true
				randomWander = 0
				-- Move toward the room entrance.
				isMovingTowardRoom = 1
			end


			if stepsInRoom == STEPS_UNTIL_PROBABILITY then
				stepsInRoom = 0
				if robot.random.exponential(1 + (roomQuality * robotsInSameRoom/2)) > 1 then
					leaveRoom = true
					randomWander = 0
					-- Move toward the room entrance.
					isMovingTowardRoom = 1
				end
			else
				stepsInRoom = stepsInRoom + 1
			end


		elseif inCentralRoom then
			roomQuality = 0
			roomMissingAttribute = 0
			roomSpecialAttribute = 0
			if roomWanderSteps == MAX_CENTRAL_ROOM_WANDER_STEPS then
				roomWanderSteps = 0
				-- Stop wandering, start searching a new room.
				randomWander = 0
			else
				roomWanderSteps = roomWanderSteps + 1
			end
		end
	end


	-- Obstacle avoidance (obstacleAvoidance_sta.lua)
	if avoid_obstacle then
		if(turning_right == 1) then
			robot.wheels.set_velocity(5,-5)
		else
			robot.wheels.set_velocity(-5,5)
		end
	end
	-- Obstacle avoidance [end]

end

--[[ Broadcast the qualities and the room number.
	[1] Room quality
	[2] Ground colour
	[3] Light intensity
	[4] Room number

	Beware that we convert the range [0, 1] of the qualities to [0, 255]
	of the range and bearing system.

	Input: 	- Robot type, either "fbG" or "fbL".
			- Room quality [0, 1]
			- Room special attribute of the robot (ground colour or light) [0, 1]
			- Room number
	Return: The corresponding quality [0,1]
	 ]]
function broadcastQualities(robotType, roomQuality, roomSpecialAttribute, roomNumber)
	if robotType == "fbG" then
		-- Ground robot, special attribute is in second position
		robot.range_and_bearing.set_data(2, roomSpecialAttribute*255)
	elseif robotType == "fbL" then
		-- Ground robot, special attribute is in third position
		robot.range_and_bearing.set_data(3, roomSpecialAttribute*255)
	end
	robot.range_and_bearing.set_data(1, roomQuality*255)
	robot.range_and_bearing.set_data(4, roomNumber)
end



--[[ Measure the attribute specific to the robot: ground colour or light
	intensity.
	In the case of the light intensity, the robot first has to turn toward
	the light source by having the highest intensity in sensor 1 or 24.
	Then, it takes one step toward that source and computes
		light(i) - light(i-1) / (step size)^2
	Note that this method is the result of experimentation in the simulation
	and is wrong. It should be updated to yield the right result.

	Input: Robot type, either "fbG" or "fbL".
	Return: The corresponding quality [0,1]
	 ]]
function getSpecialAttribute(robotType)
	if robotType == "fbG" then
		-- Colour of the ground
		return robot.motor_ground[1].value
	elseif robotType == "fbL" then
		-- Intensity of the light
		-- We will get the raw values from the sensors  and keep the max.
		-- Then we set the quality as the value divided by
		-- the distance to the source. We suppose the relation between the intensity and
		-- the distance follows the inverse-square law:
		-- Intensity \propto 1/(distance^2)
		-- 
		-- This method is wrong, it should be updated to have better results.
		local maxLight = 0
		local maxLightIdx = 0
		for i = 1,24 do
			if robot.light[i].value > maxLight then
				maxLight = robot.light[i].value
				maxLightIdx = i
			end
		end
		if maxLightIdx == 0 then
			isMovingTowardLight = 0
			return 0
		elseif maxLightIdx > 1 and maxLightIdx < 13 then
			-- Light is on the left, turn to the left
			robot.	wheels.set_velocity(-2, 2)
			isMovingTowardLight = 0
			return 0
		elseif maxLightIdx > 12 and maxLightIdx < 24 then
			-- Light is on the right, turn to the right
			robot.	wheels.set_velocity(2, -2)
			isMovingTowardLight = 0
			return 0
		elseif (maxLightIdx == 1 or maxLightIdx == 24) and isMovingTowardLight == 0 then
			-- Robot is facing the light (roughly, good enough)
			robot.	wheels.set_velocity(5, 5)
			isMovingTowardLight = 1
			saveLightValue = maxLight
			return 0
		elseif isMovingTowardLight == 1 then
			return ( (maxLight - saveLightValue)/(math.pow( robot.wheels.distance_left/10, 2)) )
		end
	end -- RobotType
end




--[[ Count the number of robots in the same room using the
	omnidirectional camera.

	Return: The number of robots detected.
	 ]]
function countRobotsInSameRoom()
	local robotCnt = 0
	for i = 1, #robot.range_and_bearing do
		if roomNumber == robot.range_and_bearing[i].data[4] then
			robotCnt = robotCnt + 1
		end
	end
	return robotCnt
end


--[[ Get info from other robots using the 'range and bearing' system.
	Based on the robot type, it fetches the attribute it could not
	measure, and the room quality.
	Both could be equal to 0.
	The data is divided by 255 (the range of data[]) to bring the qualities
	back to the [0, 1] range.

	Input: Robot type, either "fbG" or "fbL".
	Return: The corresponding quality [0,1]
	 ]]
function getInfo(robotType)
	local roomQuality = 0
	local uniqueQuality = 0
	for i = 1, #robot.range_and_bearing do
		if roomNumber == robot.range_and_bearing[i].data[4] then
			-- If the robots are in the same room
			if robot.range_and_bearing[i].data[1] ~= 0 then
				-- Do not care if the quality == 0
				roomQuality = (robot.range_and_bearing[i].data[1])/255
			end

			if robotType == "fbG" then
				-- Get light quality from others
				if robot.range_and_bearing[i].data[3] ~= 0 then
					uniqueQuality = (robot.range_and_bearing[i].data[3])/255
				end
			elseif robotType == "fbL" then
				-- Get ground quality from others
				if robot.range_and_bearing[i].data[2] ~= 0 then
					uniqueQuality = (robot.range_and_bearing[i].data[2])/255
				end
			end
		end

	end
	return roomQuality, uniqueQuality
end



--[[ Count the number of objects in the room using the omnidirectional camera
	and deduce the 'sub-quality' v_o.
	Only the objects in front of the robot are counted, avoiding this way to
	count the objects in the other rooms.

	Return: The corresponding quality [0,1]
	 ]]
function objectQuality()
local objectCnt = 0
	for i = 1, #robot.colored_blob_omnidirectional_camera do
		if rgbToString(robot.colored_blob_omnidirectional_camera[i].color.red,
							robot.colored_blob_omnidirectional_camera[i].color.green,
							robot.colored_blob_omnidirectional_camera[i].color.blue) == "green" then
			-- If see green (object)
			if ( 	( robot.colored_blob_omnidirectional_camera[i].angle < math.pi / 2 ) and
					( robot.colored_blob_omnidirectional_camera[i].angle > 0) )
				or
				(	( robot.colored_blob_omnidirectional_camera[i].angle > math.pi / -2) and
					( robot.colored_blob_omnidirectional_camera[i].angle < 0) )
				then
				-- If the object is in front of the robot (do not count objects from
				-- other rooms he may see from here) 
				objectCnt = objectCnt + 1
			end
		end
	end
-- Convert the object count into quality
return (objectCnt-2)/10
end


--[[ Find the closest room using the omnidirectional camera.
	Return: - The closest room number [0, 3]
			- The distance to the closest room in centimeters
			- The angle to the closest room in radians.
	 ]]
function findClosestRoom()

	for i = 1, #robot.colored_blob_omnidirectional_camera do
	local roomSeen = -1
		if rgbToString(robot.colored_blob_omnidirectional_camera[i].color.red,
							robot.colored_blob_omnidirectional_camera[i].color.green,
							robot.colored_blob_omnidirectional_camera[i].color.blue) == "magenta" then
			roomSeen = 0
		elseif rgbToString(robot.colored_blob_omnidirectional_camera[i].color.red,
								robot.colored_blob_omnidirectional_camera[i].color.green,
								robot.colored_blob_omnidirectional_camera[i].color.blue) == "blue" then
			roomSeen = 1
		elseif rgbToString(robot.colored_blob_omnidirectional_camera[i].color.red,
								robot.colored_blob_omnidirectional_camera[i].color.green,
								robot.colored_blob_omnidirectional_camera[i].color.blue) == "orange" then
			roomSeen = 2
		elseif rgbToString(robot.colored_blob_omnidirectional_camera[i].color.red,
								robot.colored_blob_omnidirectional_camera[i].color.green,
								robot.colored_blob_omnidirectional_camera[i].color.blue) == "red" then
			roomSeen = 3
		end

		if (robot.colored_blob_omnidirectional_camera[i].distance < closestRoomDistance) and roomSeen ~= -1 then
			-- The current room analyzed is closer and is a room, not a robot.
			closestRoomDistance = robot.colored_blob_omnidirectional_camera[i].distance
			closestRoom = roomSeen
			closestRoomAngle = robot.colored_blob_omnidirectional_camera[i].angle
		end

	end --for i = 1, #robot.colored_blob_omnidirectional_camera do

	return closestRoom, closestRoomDistance, closestRoomAngle
end




--[[ Input: RGB components [0, 255]
	Return: a string corresponding to the colour name.
	 ]]
function rgbToString(r, g, b)
	if (r == 255) and (g == 0) and (b == 255) then
		return "magenta"
	elseif (r == 0) and (g == 0) and (b == 255) then
		return "blue"
	elseif (r == 255) and (g == 140) and (b == 0) then
		return "orange"
	elseif (r == 255) and (g == 0) and (b == 0) then
		return "red"
	elseif (r == 255) and (g == 255) and (b == 0) then
		return "yellow"
	elseif (r == 0) and (g == 255) and (b == 0) then
		return "green"
	elseif (r == 0) and (g == 255) and (b == 255) then
		return "cyan"
	else
		return "THIS IS NOT A COLOUR, FOOL"
	end
end


--[[ This function is executed every time you press the 'reset'
     button in the GUI. It is supposed to restore the state
     of the controller to whatever it was right after init() was
     called. The state of sensors and actuators is reset
     automatically by ARGoS. ]]
function reset()
   -- put your code here
	robot.leds.set_all_colors("black")
	robot.colored_blob_omnidirectional_camera.enable()
end



--[[ This function is executed only once, when the robot is removed
     from the simulation ]]
function destroy()
   -- put your code here
end
