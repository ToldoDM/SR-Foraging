-- Global variables
STRAIGH_VELOCITY = 15
TURN_VELOCITY = 5
-- Red
CONTEST_COLOR = "red"
CONTEST_R = 255
CONTEST_G = 0
CONTEST_B = 0
-- Green
EXPLORING_COLOR = "green"
EXPLORING_R = 0
EXPLORING_G = 255
EXPLORING_B = 0
-- Blue
HAVE_FOOD_COLOR = "blue"
HAVE_FOOD_R = 0
HAVE_FOOD_G = 0
HAVE_FOOD_B = 255
-- Yellow
GOING_FOOD_COLOR = "yellow"
GOING_FOOD_R = 255
GOING_FOOD_G = 255
GOING_FOOD_B = 0
-- Cyan
CHAIN1_COLOR = "cyan"
CHAIN1_R = 0
CHAIN1_G = 255
CHAIN1_B = 255
-- Magenta
CHAIN2_COLOR = "magenta"
CHAIN2_R = 255
CHAIN2_G = 0
CHAIN2_B = 255
-- White
CHAIN3_COLOR = "white"
CHAIN3_R = 255
CHAIN3_G = 255
CHAIN3_B = 255
-- Orange
SOURCE_COLOR = "orange"
SOURCE_R = 255
SOURCE_G = 165
SOURCE_B = 0
-- Purple
DEST_COLOR = "purple"
DEST_R = 128
DEST_G = 0
DEST_B = 128

-- robot states
i_am_source = false
part_of_chain = false

-- robot variables
avoid_obstacle = false
on_nest = false
source_present = false
contest = false
random_number = 0

--chain variables
reference_robot = ''
reference_angle = 0

-- Initialization function, executed when the 'execute' button is pressed
function init()
    reset()
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
function check_ground()
    local min_ground = 1
    for i = 1, 4 do
        if min_ground > robot.motor_ground[i].value then
            min_ground = robot.motor_ground[i].value
        end
    end
    return min_ground
end

function check_omnidirectional_camera()
    local closest_ref = 1000000
    local index_ref = 0
    local r = 0
    local g = 0
    local b = 0
    local distance = 0

    -- Check what the robot is seeing
    for i = 1, #robot.colored_blob_omnidirectional_camera do
        r = robot.colored_blob_omnidirectional_camera[i].color.red
        g = robot.colored_blob_omnidirectional_camera[i].color.green
        b = robot.colored_blob_omnidirectional_camera[i].color.blue
        distance = robot.colored_blob_omnidirectional_camera[i].distance

        -- check for source source_present
        if not source_present then
            -- Check if there's a contest going on this means the source will be soon establish
            source_present = (r == SOURCE_R and g == SOURCE_G and b == SOURCE_B) or
                                 (r == CONTEST_R and g == CONTEST_G and b == CONTEST_B)
        end
        -- check for closest robot reference between chain 1/2/3 and source
        if (r == CHAIN1_R and g == CHAIN1_G and b == CHAIN1_B) or (r == CHAIN2_R and g == CHAIN2_G and b == CHAIN2_B) or
            (r == CHAIN3_R and g == CHAIN3_G and b == CHAIN3_B) or (r == SOURCE_R and g == SOURCE_G and b == SOURCE_B) then
            if (distance < closest_ref) then
                closest_ref = distance
                index_ref = i
            end
        end
    end
    if index_ref ~= 0 then        
        r = robot.colored_blob_omnidirectional_camera[index_ref].color.red
        g = robot.colored_blob_omnidirectional_camera[index_ref].color.green
        b = robot.colored_blob_omnidirectional_camera[index_ref].color.blue
        reference_angle = robot.colored_blob_omnidirectional_camera[index_ref].angle
        log(reference_angle)
        if (r == CHAIN1_R and g == CHAIN1_G and b == CHAIN1_B) then
            reference_robot = CHAIN1_COLOR
        elseif (r == CHAIN2_R and g == CHAIN2_G and b == CHAIN2_B) then
            reference_robot = CHAIN2_COLOR
        elseif (r == CHAIN3_R and g == CHAIN3_G and b == CHAIN3_B) then    
            reference_robot = CHAIN3_COLOR   
        elseif (r == SOURCE_R and g == SOURCE_G and b == SOURCE_B) then   
            reference_robot = SOURCE_COLOR             
        end
        robot.leds.set_all_colors(EXPLORING_R, EXPLORING_G, EXPLORING_B) 
    elseif not (i_am_source or i_am_dest or contest or part_of_chain) then
        robot.leds.set_all_colors(0, 0, 0) 
    end
end

-- Function to process the reference to the robot
function process_robot_reference()
    if reference_robot == SOURCE_COLOR then -- Stear torwards the source and then turn
        if reference_angle > 0.2 or reference_angle < -0.2 then
            robot.wheels.set_velocity(TURN_VELOCITY,-TURN_VELOCITY)
        else
            robot.wheels.set_velocity(STRAIGH_VELOCITY,STRAIGH_VELOCITY)
        end
    end
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
    on_dest = mean == 0
end

-- Function to process range and bearing sensor data
function get_communication(byte_index)
    local list = {}
    for i, reading in ipairs(robot.range_and_bearing) do
        table.insert(list, reading.data[byte_index])
    end
    return list
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

-- This method will handle the robot sources line nest and destination
function process_sources()
    if on_nest then
        -- If there is no robot as source then i'm gonna try to put myself as a source
        if not (source_present) then
            -- I'm gonna enter in a contest status
            robot.leds.set_all_colors(CONTEST_R, CONTEST_G, CONTEST_B)
            source_present = true
            contest_steps = 100
            contest = true
            random_number = robot.random.uniform_int(255)
            robot.range_and_bearing.set_data(1, random_number)
        else
            if contest then
                contest_steps = contest_steps - 1
                local contest_list = get_communication(1)

                i_am_source = true
                for i, c_value in ipairs(contest_list) do
                    if c_value > random_number then
                        i_am_source = false
                    elseif c_value == random_number then
                        random_number = robot.random.uniform_int(255)
                        robot.range_and_bearing.set_data(1, random_number)
                    end
                end

                if (contest_steps == 0) then
                    robot.leds.set_all_colors(SOURCE_R, SOURCE_G, SOURCE_B)
                    contest = false
                    if not i_am_source then
                        robot.wheels.set_velocity(STRAIGH_VELOCITY, STRAIGH_VELOCITY)
                        robot.leds.set_all_colors(0, 0, 0)
                    end
                end
            end
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
    ground = check_ground()
    check_omnidirectional_camera()

    -- THINK
    obstacle_avoidance()
    ground_handling()
    process_sources()

    -- ACT
    if i_am_source or i_am_dest or contest or part_of_chain then
        robot.wheels.set_velocity(0, 0)
        return
    else
        -- Going around randomly through the arena avoiding other robots
        if (not avoid_obstacle) then
            process_robot_reference()
        else
            try_turn()
        end
    end
end

-- Reset function, executed when the 'reset' button is pressed
function reset()
   -- robot states
    i_am_source = false
    part_of_chain = false

    -- robot variables
    avoid_obstacle = false
    on_nest = false
    source_present = false
    contest = false
    random_number = 0

    --chain variables
    reference_robot = ''
    reference_angle = 0

    robot.colored_blob_omnidirectional_camera.enable()
    robot.wheels.set_velocity(STRAIGH_VELOCITY, STRAIGH_VELOCITY)
end

-- Destroy function, executed when the robot is removed from the simulation
function destroy()
end

