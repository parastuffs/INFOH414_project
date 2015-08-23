-- Put your global variables here
avoid_obstacle = false
inhibateObstacleAvoidance = false

robotType = ""
robotID = 0

isTurning = 0
isMovingTowardRoom = 0
randomWander = 0
inRoom = 0
inCentralRoom = false
iThinkThisIsTheBestRoom = false
-- MAX_ROOM_WANDER_STEPS = 20
-- MAX_STEPS_IN_ROOM = 30
MAX_CENTRAL_ROOM_WANDER_STEPS = 350
roomWanderSteps = 0
transitionSteps = 0
-- leaveRoom = false
stetpsUntilLeave = 0

closestRoomDistance = 255
-- closestRoomAngle = 0
targetRoomDistance = 255
targetRoomAngle = 0
closestRoom = -1
targetRoom = -1
roomNumber = -1
INHIBITION_RADIUS = 25

roomQuality = 0
roomMissingAttribute = 0
roomSpecialAttribute = 0
roomObjects = 0
bestRoomQuality = 0

stepsInRoom = 0
STEPS_UNTIL_LEAVE = 200
STEPS_UNTIL_LEAVE_BEST_ROOM = 500

roomTransition = false


--[[ This function is executed every time you press the 'execute'
     button ]]
function init()
	isMovingTowardRoom = 1
	inCentralRoom = true
	robotID = robot.id -- For dynamic analysis
	closestRoomDistance = 255
	-- closestRoomAngle = 0
	inRoom = 0
	iThinkThisIsTheBestRoom = false
end



--[[ This function is executed at each time step
     It must contain the logic of your controller ]]
function step()
	robot.colored_blob_omnidirectional_camera.enable() -- maybe move this to init()

	-- closestRoomAngle = 0
	closestRoomDistance = 255
	targetRoomDistance = 255
	targetRoomAngle = 0

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

	-- robotsInSameRoom = countRobotsInSameRoom() -- TODO may be useless


	closestRoom = findClosestRoom()
	targetRoom = closestRoom
  
	if inRoom == 1 then
		roomQuality = senseRoomQuality()
	elseif inCentralRoom then
		-- Get other's quality and maybe change the target.
		roomNumber, roomQuality = senseBestRoom()
		if roomNumber ~= -1 then
			-- Change the target room only if the best room sensed is different from -1.
			-- It could be that you did not sense any better quality than yours,
			-- but that your room is still -1 (none visited).
			targetRoom = roomNumber
			iThinkThisIsTheBestRoom = true
		end
	end
	targetRoomAngle, targetRoomDistance = whereIsTheRoom(targetRoom)

	-- -------------------------------
	-- 			THINK
	-- -------------------------------

	if(not inhibateObstacleAvoidance) then
		-- Obstacle avoidance (obstacleAvoidance_sta.lua)
		if(not avoid_obstacle) then
			if(obstacle) then
				avoid_obstacle = true
				turning_steps = robot.random.uniform_int(4,30)
				-- turning_right = robot.random.bernoulli()
				turning_right = 1
			end
		else
			turning_steps = turning_steps - 1
			if(turning_steps == 0) then 
				avoid_obstacle = false
			end
		end
		-- Obstacle avoidance [end]
	end



	-- -------------------------------
	-- 			ACT
	-- -------------------------------

	-- Broadcast only if you have a quality to broadcast.
	if roomQuality > 0 and inCentralRoom then
		broadcastQuality()
		log("[" .. roomNumber .. "_" .. robot.id .. "]: " .. roomQuality)
	end

	if isMovingTowardRoom == 1 then
		-- Turn toward closest room
	
		--  /^\
		-- /_!_\ The angles go from 0 to pi and then -pi to 0, not 0 to 2*pi
		-- like any sane person would suppose.
		if (targetRoomAngle > 0.2) then
			-- The room is on the left
			robot.wheels.set_velocity(-5, 5)
			isTurning = 1
		elseif (targetRoomAngle < -0.2) then
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

		if targetRoomDistance < INHIBITION_RADIUS then
			-- Final approach
			isMovingTowardRoom = 0
			-- randomWander = 1
			roomTransition = true
			inhibateObstacleAvoidance = true
		else
			inhibateObstacleAvoidance = false
		end
		
	end -- if isMovingTowardRoom == 1 then


	if roomTransition then
		-- Move forward for (2*INHIBITION_RADIUS) steps in order to change room.
		robot.wheels.set_velocity(5, 5)
		if transitionSteps == (2*INHIBITION_RADIUS) then
			-- We are out of the inhibition radius, we are then...
			if inCentralRoom then
				-- ... either in a room...
				inRoom = 1
				inCentralRoom = false
			elseif inRoom == 1 then
				-- ... or in the central room.
				inRoom = 0
				inCentralRoom = true
			end
			stepsInRoom = 0
			roomNumber = targetRoom
			transitionSteps = 0
			randomWander = 1
			roomTransition = false

			-- Turn the inhibition back off
			inhibateObstacleAvoidance = true
		else
			transitionSteps = transitionSteps + 1
		end

	elseif randomWander == 1 then

		if inRoom == 1 then
			stepsInRoom = stepsInRoom + 1
			roomQuality = senseRoomQuality()
			-- broadcastQuality()
			-- log("[" .. roomNumber .. "_" .. robot.id .. "]: " .. roomQuality)

			-- if roomQuality >= bestRoomQuality then
			-- 	bestRoomQuality = roomQuality
			-- else
			-- 	-- Lesser quality room, do not waste more time in here.
			-- 	leaveRoom = true
			-- 	randomWander = 0
			-- 	-- Move toward the room entrance.
			-- 	isMovingTowardRoom = 1
			-- end

			if stepsInRoom == STEPS_UNTIL_LEAVE and (not iThinkThisIsTheBestRoom) then
				-- This branch should be used only for the first visited room that has not been
				-- identified has the best room from broadcast sensing.
				stepsInRoom = 0
				-- leaveRoom = true
				randomWander = 0
				-- Move toward the room entrance.
				isMovingTowardRoom = 1
			elseif stepsInRoom == STEPS_UNTIL_LEAVE_BEST_ROOM and iThinkThisIsTheBestRoom then
				stepsInRoom = 0
				-- leaveRoom = true
				randomWander = 0
				-- Move toward the room entrance.
				isMovingTowardRoom = 1
			end


		elseif inCentralRoom then
			-- roomQuality = 0
			if roomWanderSteps == MAX_CENTRAL_ROOM_WANDER_STEPS then
				roomWanderSteps = 0
				-- Stop wandering, start searching a new room.
				randomWander = 0
				isMovingTowardRoom = 1
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


function senseRoomQuality()
	local groundQual = robot.motor_ground[1].value
	local objQual = objectQuality()
	return (groundQual + objQual)/2
end



--[[ Count the number of robots in the same room using the
	omnidirectional camera.

	Return: The number of robots detected.
	 ]]
function countRobotsInSameRoom()
	local robotCnt = 0
	return robotCnt
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
		end

	end --for i = 1, #robot.colored_blob_omnidirectional_camera do

	return closestRoom
end

function whereIsTheRoom(roomNumber)
	local distance = 255
	local angle = 0
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

		if roomSeen == roomNumber then
			distance = robot.colored_blob_omnidirectional_camera[i].distance
			angle = robot.colored_blob_omnidirectional_camera[i].angle
		end

	end --for i = 1, #robot.colored_blob_omnidirectional_camera do
	return angle, distance
end


function senseBestRoom()
	local bestRoom = roomNumber -- Set the best room number as the last visited room
	local bestQuality = roomQuality -- Set the best quality as the last room quality
	local sensedQuality
	for i = 1, #robot.colored_blob_omnidirectional_camera do
		if robot.colored_blob_omnidirectional_camera[i].color.green == 42 then
			-- Colour sensed is a quality
			sensedQuality = (robot.colored_blob_omnidirectional_camera[i].color.blue-20)/200
			if sensedQuality > bestQuality then
				-- Sensed quality is better
				bestQuality = sensedQuality
				bestRoom = (robot.colored_blob_omnidirectional_camera[i].color.red/40)-1
			end
		end
	end
	return bestRoom, bestQuality
end


--[[ Broadcast the quality of the last visited room using the LEDs.
	The quality and room number are encoded respectively in the red and blur LEDs:
	- red = room number + 1 times 40. Hence room 0 = 40, room 1 = 80, etc.
	- green = 42, tag saying this is a quality
	- blue = quality times 200 + 20. The quality will hence span from 20 to 220, discretely.
	]]
function broadcastQuality()
	robot.leds.set_single_color(13, (roomNumber+1)*40, 42, (roomQuality*200)+20)
end


--[[ Decode the quality and the room from RGB components
	input: r, g, b: red, green, blue [0, 255]
	The room number is on the red component, the quality on the blue.
]]
function decodeQuality(r, g, b)
	local quality
	local room
	room = (r/40)-1
	quality = (b-20)/40
	return quality, room
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