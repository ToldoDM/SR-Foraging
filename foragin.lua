-- Constants
COLORS = {
   CONTEST_SOURCE = {name = "red1", r = 255, g = 1, b = 1},
   EXPLORING = {name = "white", r = 255, g = 255, b = 255},
   HAVE_FOOD = {name = "green", r = 0, g = 255, b = 0},
   GOING_FOOD = {name = "red", r = 255, g = 0, b = 0},
   SOURCE = {name = "magenta", r = 255, g = 0, b = 255},
   UBER_EATS = {name = "cyan", r = 0, g = 255, b = 255},
   ZERO = {name = "black", r = 0, g = 0, b = 0},
}

VELOCITIES = {
   STRAIGHT = 15,
   BASE = 7.5,
   SEE_SOURCE = 8,
   TURN = 5
}

-- Global variables
robot_states = {
  i_am_source = false,
  contest = false,
  harvest_food = false,
}

robot_vars = {
  avoid_obstacle = false,
  source_present = false,
  turning_steps = 0,
  on_nest = false,
  on_dest = false,
  turning_right = false,
  on_forbidden = false,
  contest_steps = 0,
  unclogging_steps = 0,
  random_number = 0,
  go_back_to_base = false,
  wait_unclogging = false,
  max_source_angle = 0,
  color_to_see_source = false,
}


function set_robot_leds_color(color)
  robot.leds.set_all_colors(color.r, color.g, color.b) 
end

function get_blob_color(blob)
  return blob.color.red, blob.color.green, blob.color.blue
end

function is_color(blob, color_ref)
  local r, g, b = get_blob_color(blob)
  return r == color_ref.r and g == color_ref.g and b == color_ref.b
end

function is_source_or_contest_or_harvest(blob)
  return is_color(blob, COLORS.SOURCE) or is_color(blob, COLORS.CONTEST_SOURCE) or is_harvest(blob)
end

function is_harvest(blob)
  return is_color(blob, COLORS.GOING_FOOD) or is_color(blob, COLORS.HAVE_FOOD)
end

function check_omnidirectional_camera()
  robot_vars.max_source_angle = 0
  robot_vars.color_to_see_source = false
  local source_priority = false

  -- Check my surroundings
  for i, blob in ipairs(robot.colored_blob_omnidirectional_camera) do
      -- If I see the source or other robot harvesting food then the source is present
      robot_vars.source_present = robot_vars.source_present or is_source_or_contest_or_harvest(blob)
      -- If I see the source or other robot harvesting food then my role is harvesting food
      robot_states.harvest_food = robot_states.harvest_food or is_color(blob, COLORS.SOURCE) or is_harvest(blob)

      -- Check for reference for stearing torwards the source or robot that sees the source
      if is_color(blob, COLORS.SOURCE) then
         robot_vars.max_source_angle = blob.angle
         source_priority = true
         robot_vars.color_to_see_source = true
      elseif is_color(blob, COLORS.UBER_EATS) and not source_priority then
         robot_vars.max_source_angle = blob.angle
         robot_vars.color_to_see_source = false
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
  -- I treat stepping on a forbidden area as avoiding a collision
  if not obstacle then
     obstacle = (front_left == 0.2 or front_right == 0.2) and not (rear_right == 0.2 and rear_left == 0.2) and robot_vars.go_back_to_base
  end
  -- If I am the source i don't want to exit the nest
  if robot_states.i_am_source then
     if not obstacle then
        obstacle = (front_left == 0.6 or front_right == 0.6)
     end
  end
  robot_vars.on_forbidden = front_left == 0.2 and front_right == 0.2 and (rear_right == 0.2 or rear_left == 0.2) -- At least 3 sensors are in the forbidden area
  robot_vars.on_nest = mean == 1
  robot_vars.on_dest = mean == 0
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

-- Function to handle obstacle avoidance logic
function obstacle_avoidance()
   -- If I have just detect an obtacle then i choose randomly in which direction and for how long to steer
   if (not robot_vars.avoid_obstacle) then
       if (obstacle) then
           robot_vars.avoid_obstacle = true
           robot_vars.turning_steps = robot.random.uniform_int(4, 40)
           robot_vars.turning_right = robot.random.bernoulli()
       end
   else
       robot_vars.turning_steps = robot_vars.turning_steps - 1
       if (robot_vars.turning_steps == 0) then
           robot_vars.avoid_obstacle = false
       end
   end
end

-- Function to try turning depending on the turning_right value
function try_turn()
   robot_vars.unclogging_steps = robot.random.uniform_int(10, 40) -- This is used when is in GOING_FOOD state, as it could encounter some obstables
   robot_vars.wait_unclogging = true
   if (robot_vars.turning_right) then
       robot.wheels.set_velocity(VELOCITIES.TURN, -VELOCITIES.TURN)
   else
       robot.wheels.set_velocity(-VELOCITIES.TURN, VELOCITIES.TURN)
   end
end

-- Function to process range and bearing sensor data
function get_communication(byte_index)
   local list = {}
   for i, reading in ipairs(robot.range_and_bearing) do
       table.insert(list, reading.data[byte_index])
   end
   return list
end
  
-- This method will handle the robot source nest
function process_source()
   if robot_vars.on_nest then
      if not (robot_vars.source_present) then
         -- Enter contest
         set_robot_leds_color(COLORS.CONTEST_SOURCE)
         robot_vars.source_present = true
         robot_vars.contest_steps = 100
         robot_states.contest = true
         robot_vars.random_number = robot.random.uniform_int(255) -- Draw a random number
         robot.range_and_bearing.set_data(1, robot_vars.random_number) --Expose the numer to others
      else
         if robot_states.contest then
            robot_vars.contest_steps = robot_vars.contest_steps - 1
            local contest_list = get_communication(1) -- Get contesters draw number
   
            robot_states.i_am_source = true
            for i, c_value in ipairs(contest_list) do
               if c_value > robot_vars.random_number then -- Check if I have the highest value
                     robot_states.i_am_source = false
               elseif c_value == robot_vars.random_number then -- If same highest value then draw new number
                     robot_vars.random_number = robot.random.uniform_int(255)
                     robot.range_and_bearing.set_data(1, robot_vars.random_number)
               end
            end
   
            -- Exit the contest and auto assign role
            if (robot_vars.contest_steps == 0) then
               robot_states.contest = false
               robot.wheels.set_velocity(VELOCITIES.STRAIGHT, VELOCITIES.STRAIGHT)
               set_robot_leds_color(COLORS.ZERO)
               if robot_states.i_am_source then
                  set_robot_leds_color(COLORS.SOURCE)
               else
                  robot_states.harvest_food = true
               end
            end
         end
      end
   end
end

-- This method actually stear torward a reference robot that could be the SOURCE (nest) or the UBER_EATS state (delivering)
function turn_towards_source()   
  -- If the reference angle is higher than 0.2 then stear
  if math.abs(robot_vars.max_source_angle) > 0.2 then
     if robot_vars.wait_unclogging then -- if I'm waiting to unclog, then i just steared, so i'll go straight for a while
         if robot_vars.color_to_see_source then -- If i see the source, I slow down
            robot.wheels.set_velocity(VELOCITIES.SEE_SOURCE, VELOCITIES.SEE_SOURCE)
         else
            robot.wheels.set_velocity(VELOCITIES.STRAIGHT, VELOCITIES.STRAIGHT)
         end

         robot_vars.unclogging_steps = robot_vars.unclogging_steps - 1
         if robot_vars.unclogging_steps == 0 then
            robot_vars.wait_unclogging = false
         end
     else
        if robot_vars.max_source_angle > 0 then -- Stear torwards the reference robot
           robot.wheels.set_velocity(-VELOCITIES.TURN, VELOCITIES.TURN)
        else
           robot.wheels.set_velocity(VELOCITIES.TURN, -VELOCITIES.TURN)
        end
     end     
  else
      if robot_vars.color_to_see_source then -- If i see the source, I slow down
         robot.wheels.set_velocity(VELOCITIES.SEE_SOURCE, VELOCITIES.SEE_SOURCE)
      else
         robot.wheels.set_velocity(VELOCITIES.STRAIGHT, VELOCITIES.STRAIGHT)
      end
  end   
end

function turn_towards_light()
  local max_light_intensity = -1
  local max_light_angle = 0
  
  -- Iterate over all light sensors
  for i, sensor in ipairs(robot.light) do
     -- If the current sensor has a higher intensity than our previous max
     if sensor.value > max_light_intensity then
        max_light_intensity = sensor.value
        max_light_angle = sensor.angle
     end
  end
  
  -- If the light angle is higher than 0.2 then stear
  if math.abs(max_light_angle) > 0.2 then
     if robot_vars.wait_unclogging then -- if I'm waiting to unclog, then i just steared, so i'll go straight for a while
        robot.wheels.set_velocity(VELOCITIES.STRAIGHT, VELOCITIES.STRAIGHT)

        robot_vars.unclogging_steps = robot_vars.unclogging_steps - 1
        if robot_vars.unclogging_steps == 0 then
           robot_vars.wait_unclogging = false
        end
     else
        if max_light_angle > 0 then  -- Stear torwards the light
           robot.wheels.set_velocity(-VELOCITIES.TURN, VELOCITIES.TURN)
        else
           robot.wheels.set_velocity(VELOCITIES.TURN, -VELOCITIES.TURN)
        end
     end     
  else
     robot.wheels.set_velocity(VELOCITIES.STRAIGHT, VELOCITIES.STRAIGHT)
  end   
end

function harvest_or_base()
   if robot_states.harvest_food then
      if robot_vars.on_dest then
         robot_vars.go_back_to_base = true
      elseif robot_vars.on_nest or robot_vars.on_forbidden then
         robot_vars.go_back_to_base = false
      end
   end
end

--[[ This function is executed every time you press the 'execute' button ]]
function init()
   reset()
end 


function step()
   -- SENSE
   obstacle = check_obstacle()
   ground_handling()
   check_omnidirectional_camera()

   -- THINK
   obstacle_avoidance()
   process_source()
   harvest_or_base()

  -- ACT
  if robot_states.i_am_source then
     if (not robot_vars.avoid_obstacle) then -- Go straight if there aren't obstacles
        robot.wheels.set_velocity(VELOCITIES.BASE, VELOCITIES.BASE)
     else
           robot_vars.turning_right = true -- Always turn in the same direction
           try_turn()
     end
     return
  elseif robot_states.contest then -- If you are in a contest, stay were you are
     robot.wheels.set_velocity(0, 0)
     return      
  else
     -- Going around randomly through the arena avoiding other robots
     if (not robot_vars.avoid_obstacle) then
        if robot_states.harvest_food then 
           if robot_vars.go_back_to_base then
              if robot_vars.color_to_see_source then -- If i see the nest i change my color to UBER_EATS (delivery)
                 set_robot_leds_color(COLORS.UBER_EATS)
              else
                 set_robot_leds_color(COLORS.HAVE_FOOD)                     
              end
              -- Stear torwards the reference robot
              turn_towards_source()
           else
              set_robot_leds_color(COLORS.GOING_FOOD)
              turn_towards_light()          
           end
        else
           robot.wheels.set_velocity(VELOCITIES.STRAIGHT, VELOCITIES.STRAIGHT)
        end
     else
           try_turn()
     end
  end
end
      
 
 
 
 --[[ This function is executed every time you press the 'reset'
      button in the GUI. It is supposed to restore the state
      of the controller to whatever it was right after init() was
      called. The state of sensors and actuators is reset
      automatically by ARGoS. ]]
 function reset()
   robot_states = {
      i_am_source = false,
      contest = false,
      harvest_food = false,
   }
    
   robot_vars = {
      avoid_obstacle = false,
      source_present = false,
      turning_steps = 0,
      on_nest = false,
      on_dest = false,
      turning_right = false,
      on_forbidden = false,
      contest_steps = 0,
      unclogging_steps = 0,
      random_number = 0,
      go_back_to_base = false,
      wait_unclogging = false,
      max_source_angle = 0,
      color_to_see_source = false,
   }   


   robot.colored_blob_omnidirectional_camera.enable()
   robot.wheels.set_velocity(VELOCITIES.STRAIGHT, VELOCITIES.STRAIGHT)
   set_robot_leds_color(COLORS.EXPLORING)
 end
 
 
 
 --[[ This function is executed only once, when the robot is removed
      from the simulation ]]
 function destroy()
    -- put your code here
 end
 