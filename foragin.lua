-- Global variables
STRAIGH_VELOCITY = 15
TURN_VELOCITY = 5

-- robots stattes
avoid_obstacle = false
on_nest = false

-- Initialization function, executed when the 'execute' button is pressed
function init()
end

-- Function to check for obstacle using front left and right sensors
function check_obstacle()
    for i = 1, 4 do -- Check the first front left sensors
        if (robot.proximity[i].value > 0.2) then
            return true
        end
    end
    for i = 20, 24 do -- Check the last front right sensors
        if (robot.proximity[i].value > 0.2) then
            return true
        end
    end
    return false
end

-- Function to calculate ground average using motor ground sensor values
function process_ground()
    local min_ground = 1
    for i = 1, 4 do
        if min_ground > robot.motor_ground[i].value then
            min_ground = robot.motor_ground[i].value 
        end
    end
    return min_ground
end

-- Function to process ground data
function ground_handling()
    -- white is 1
    -- walkable ground is 0.6
    -- food drop is 0.2
    -- black is 0
    local front_left = robot.motor_ground[1].value 
    local front_right = robot.motor_ground[4].value 
    local rear_left = robot.motor_ground[2].value 
    local rear_right = robot.motor_ground[3].value 

    local mean = (front_left + front_right + rear_left + rear_right) / 4
    on_nest = mean == 1
end

-- Function to process range and bearing sensor data
function process_communication()
    local target_bearing = 0
    return target_bearing
end

-- Function to handle obstacle avoidance logic
function obstacle_avoidance()
    if (not avoid_obstacle) then
        if (obstacle) then
            avoid_obstacle = true
            turning_steps = robot.random.uniform_int(4, 30)
            turning_right = robot.random.bernoulli()
        end
    else
        turning_steps = turning_steps - 1
        if (turning_steps == 0) then
            avoid_obstacle = false
        end
    end
end

-- Function to try turning depending on the turning_right value
function try_turn()
    if (turning_right) then
        robot.wheels.set_velocity(TURN_VELOCITY, -TURN_VELOCITY)
    else
        robot.wheels.set_velocity(-TURN_VELOCITY, TURN_VELOCITY)
    end
end

-- Main function executed at each time step, containing the logic of the controller
function step()
    -- SENSE
    obstacle = check_obstacle()
    ground = process_ground()    
    local target_bearing = process_communication()

    -- THINK
    obstacle_avoidance()

    -- ACT
    if (not avoid_obstacle) then
        if (target_detected) then
            -- Turn until target bearing is 0
            if (target_bearing ~= 0) then
                robot.wheels.set_velocity(-STRAIGH_VELOCITY, STRAIGH_VELOCITY)
            else
                robot.wheels.set_velocity(STRAIGH_VELOCITY, STRAIGH_VELOCITY)
            end
        else
            robot.wheels.set_velocity(STRAIGH_VELOCITY, STRAIGH_VELOCITY)
        end
    else
        try_turn()
    end
end

-- Reset function, executed when the 'reset' button is pressed
function reset()
end

-- Destroy function, executed when the robot is removed from the simulation
function destroy()
end

