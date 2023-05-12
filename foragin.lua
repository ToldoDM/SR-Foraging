-- Constants
COLORS = {
    CONTEST_SOURCE = {name = "red1", r = 255, g = 0, b = 0},
    CONTEST_DEST = {name = "red2", r = 255, g = 1, b = 1},
    EXPLORING = {name = "green", r = 0, g = 255, b = 0},
    HAVE_FOOD = {name = "blue", r = 0, g = 0, b = 255},
    GOING_FOOD = {name = "yellow", r = 255, g = 255, b = 0},
    CHAIN1 = {name = "cyan", r = 0, g = 255, b = 255},
    CHAIN2 = {name = "magenta", r = 255, g = 0, b = 255},
    CHAIN3 = {name = "white", r = 255, g = 255, b = 255},
    SOURCE = {name = "orange", r = 255, g = 165, b = 0},
    DEST = {name = "purple", r = 128, g = 0, b = 128},
    ZERO = {name = "black", r = 0, g = 0, b = 0},
}

VELOCITIES = {
    STRAIGHT = 15,
    TURN = 5
}

-- Global variables
robot_states = {
    i_am_source = false,
    i_am_dest = false,
    part_of_chain = false,
    contest = false,
    exploring = false,
}

robot_vars = {
    avoid_obstacle = false,
    on_nest = false,
    on_dest = false,
    source_present = false,
    dest_present = false,
    random_number = 0,
    contest_steps = 0,
    turning_steps = 0,
}

chain_vars = {
    reference_robot = '',
    reference_angle = 0,
    reference_distance = 100,
    MAX_DISTANCE = 100
}

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

function get_blob_color(blob)
    return blob.color.red, blob.color.green, blob.color.blue
end

function is_color(blob, color_ref)
    local r, g, b = get_blob_color(blob)
    return r == color_ref.r and g == color_ref.g and b == color_ref.b
end

function is_source_or_contest(blob)
    return is_color(blob, COLORS.SOURCE) or is_color(blob, COLORS.CONTEST_SOURCE)
end

function is_dest_or_contest(blob)
    return is_color(blob, COLORS.DEST) or is_color(blob, COLORS.CONTEST_DEST)
end

function is_ref_color(blob)
    return is_color(blob, COLORS.CHAIN1) or 
           is_color(blob, COLORS.CHAIN2) or 
           is_color(blob, COLORS.CHAIN3) or 
           is_color(blob, COLORS.SOURCE)
end

function check_omnidirectional_camera()
    local closest_ref = 1000000
    local index_ref = 0

    for i, blob in ipairs(robot.colored_blob_omnidirectional_camera) do

        robot_vars.source_present = robot_vars.source_present or is_source_or_contest(blob)
        robot_vars.dest_present = robot_vars.dest_present or is_dest_or_contest(blob)

        if is_ref_color(blob) and blob.distance < closest_ref then
            closest_ref = blob.distance
            index_ref = i
        end
    end

    if index_ref ~= 0 then
        local ref_blob = robot.colored_blob_omnidirectional_camera[index_ref]
        chain_vars.reference_angle = ref_blob.angle

        local r, g, b = get_blob_color(ref_blob)
        if is_color(ref_blob, COLORS.CHAIN1) then
            chain_vars.reference_robot = COLORS.CHAIN1
        elseif is_color(ref_blob, COLORS.CHAIN2) then
            chain_vars.reference_robot = COLORS.CHAIN2
        elseif is_color(ref_blob, COLORS.CHAIN3) then    
            chain_vars.reference_robot = COLORS.CHAIN3   
        elseif is_color(ref_blob, COLORS.SOURCE) then   
            chain_vars.reference_robot = COLORS.SOURCE             
        end
    elseif not (robot_states.i_am_source or robot_states.i_am_dest or robot_states.contest or robot_states.part_of_chain) then
        set_robot_leds_color(COLORS.ZERO)
    end
end

function check_chain_with_camera(color_to_check)
    for i, blob in ipairs(robot.colored_blob_omnidirectional_camera) do
        if blob.distance < chain_vars.MAX_DISTANCE and is_color(blob, color_to_check) then
            chain_vars.reference_robot = color_to_check
            chain_vars.reference_angle = blob.angle
            return true
        end
    end
    return false
end

function process_robot_reference()
    if chain_vars.reference_robot == COLORS.SOURCE or chain_vars.reference_robot == COLORS.CHAIN3 then
        -- Check for chain 1 
        if check_chain_with_camera(COLORS.CHAIN1) then
            process_robot_reference()
        end
    elseif chain_vars.reference_robot == COLORS.CHAIN1 then
        -- Check for chain 2 
        if check_chain_with_camera(COLORS.CHAIN2) then
            process_robot_reference()
        end
    elseif chain_vars.reference_robot == COLORS.CHAIN2 then
        -- Check for chain 3 
        if check_chain_with_camera(COLORS.CHAIN3) then
            process_robot_reference()
        end
    end

    if math.abs(chain_vars.reference_angle) > 0.2 then 
        robot.wheels.set_velocity(VELOCITIES.TURN, -VELOCITIES.TURN) 
    else 
        robot.wheels.set_velocity(VELOCITIES.STRAIGHT, VELOCITIES.STRAIGHT) 
    end
end

function set_robot_leds_color(color)
    robot.leds.set_all_colors(color.r, color.g, color.b) 
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
    robot_vars.on_nest = mean == 1
    robot_vars.on_dest = mean == 0
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
    if (not robot_vars.avoid_obstacle) then
        if (obstacle) then
            robot_vars.avoid_obstacle = true
            robot_vars.turning_steps = robot.random.uniform_int(4, 30)
            robot_vars.turning_right = robot.random.bernoulli()
        end
    else
        robot_vars.turning_steps = robot_vars.turning_steps - 1
        if (robot_vars.turning_steps == 0) then
            robot_vars.avoid_obstacle = false
        end
    end
end

-- Helper function to handle contest
function handle_contest(contest_color, source_color, present_key, i_am_key)
    if not (robot_vars[present_key]) then
        -- Enter contest
        set_robot_leds_color(contest_color)
        robot_vars[present_key] = true
        robot_vars.contest_steps = 100
        robot_states.contest = true
        robot_vars.random_number = robot.random.uniform_int(255)
        robot.range_and_bearing.set_data(1, robot_vars.random_number)
    else
        if robot_states.contest then
            robot_vars.contest_steps = robot_vars.contest_steps - 1
            local contest_list = get_communication(1)

            robot_states[i_am_key] = true
            for i, c_value in ipairs(contest_list) do
                if c_value > robot_vars.random_number then
                    robot_states[i_am_key] = false
                elseif c_value == robot_vars.random_number then
                    robot_vars.random_number = robot.random.uniform_int(255)
                    robot.range_and_bearing.set_data(1, robot_vars.random_number)
                end
            end

            if (robot_vars.contest_steps == 0) then
                set_robot_leds_color(source_color)
                robot_states.contest = false
                if not robot_states[i_am_key] then
                    robot.wheels.set_velocity(VELOCITIES.STRAIGHT, VELOCITIES.STRAIGHT)
                    set_robot_leds_color(COLORS.ZERO)
                end
            end
        end
    end
end

-- This method will handle the robot sources line nest and destination
function process_sources()
    if robot_vars.on_nest then
        handle_contest(COLORS.CONTEST_SOURCE, COLORS.SOURCE, 'source_present', 'i_am_source')
    elseif robot_vars.on_dest then
        handle_contest(COLORS.CONTEST_DEST, COLORS.DEST, 'dest_present', 'i_am_dest')
    end
end


-- Function to try turning depending on the turning_right value
function try_turn()
    if (robot_vars.turning_right) then
        robot.wheels.set_velocity(VELOCITIES.TURN, -VELOCITIES.TURN)
    else
        robot.wheels.set_velocity(-VELOCITIES.TURN, VELOCITIES.TURN)
    end
end

-- Main function executed at each time step, containing the logic of the controller
function step()
    -- SENSE
    obstacle = check_obstacle()
    ground_handling()
    check_omnidirectional_camera()

    -- THINK
    obstacle_avoidance()
    process_sources()

    -- ACT
    if robot_states.i_am_source or robot_states.i_am_dest or robot_states.contest or robot_states.part_of_chain then
        robot.wheels.set_velocity(0, 0)
        return
    else
        -- Going around randomly through the arena avoiding other robots
        if (not robot_vars.avoid_obstacle) then
            process_robot_reference()
        else
            try_turn()
        end
    end
end

-- Reset function, executed when the 'reset' button is pressed
function reset()
    -- robot states
    robot_states.i_am_source = false
    robot_states.i_am_dest = false
    robot_states.part_of_chain = false
    robot_states.contest = false
    robot_states.exploring = false

    -- robot variables
    robot_vars.avoid_obstacle = false
    robot_vars.on_nest = false
    robot_vars.on_dest = false
    robot_vars.source_present = false
    robot_vars.dest_present = false
    robot_vars.random_number = 0

    --chain variables
    chain_vars.reference_robot = ''
    chain_vars.reference_angle = 0
    chain_vars.reference_distance = 100

    robot.colored_blob_omnidirectional_camera.enable()
    robot.wheels.set_velocity(VELOCITIES.STRAIGHT, VELOCITIES.STRAIGHT)
    set_robot_leds_color(COLORS.ZERO)
end

-- Destroy function, executed when the robot is removed from the simulation
function destroy()
end

