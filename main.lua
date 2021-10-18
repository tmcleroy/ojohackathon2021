-- gba screen res 240x160

--# Player
playerX = 0
playerY = -16
playerAnim = 0
playerFlipX = nil

scrollX = 0
scrollY = 0

playerBullets = {}
lastBulletTick = 0

enemies = {}

tileStars = true
stars = {}

--# Gameplay
STATE = 0 --#Gameplay state: 0 (title) / 1 (gameplay) / 2 (gameover) / 3 (screen fade to (re)start game
ticks = 0
score = 0
highscore = -1
ticks_anim = 0
screenshake = 0

--# ------------------------------------
--# ----- LOAD ASSETS ------
--# ------------------------------------

--# Hide the screen
fade(1)

--# Load tiles data for each layer
txtr(0, "overlay.bmp")
txtr(1, "tiles.bmp")
txtr(2, "tiles.bmp")
txtr(4, "sprites.bmp")

-- black out screen
-- fill enough vertical lines for a seamless vertical scroll
for i = 0,31,1 do 
	-- horizontal columns
	for j = 0,29,1 do 
		-- black tile
		tile(3, j, i, 62)
	end
end

if tileStars then
	--#Add random stars
	for i = 0, 25, 1 do
		--#Put a random star tile in a random position on the map
		tile(3, math.random(30), math.random(30), 62+math.random(9))
	end
end

--#Reorder the layer priority so the sprites are displayed OVER the overlay (other layers are kept to their default values)
priority(0, 2, 3, 3)

--# ----------------------------------
--# ------- GAME INIT --------
--# ----------------------------------
function init()
	
	--#Init gameplay vars
	ticks=0
	score=0
	foesTimer=60
	
	--#Reset screenshake
	screenshake=0
	scroll(2, 0, 0)
	
	--# Init player vars
	playerX=112
	playerY=130
	playerFlipX=nil
	playerAnim=1
	
	--#Erase the overlay messages
	--#For every line
	for i = 0,19,1 do 
		--#For every column
		for j = 0,30,1 do 
			--#Manually put a "blank" tile in the layer (tile id 1 in the overlay.bmp asset) - NB: there is no way to erase text with transparent tile for now
			tile(0, j, i, 1)
		end
	end

	-- draw initial score
	print("score:"..score, 0, 0)
	
	--# Play music
	-- music("music.raw", 0)
end


--# ------------------------------------
--# ----- GAME UPDATE ------
--# ------------------------------------
function update()

	--# === TICKS ===
		
	--# Count ticks (used for game timing)
	ticks = ticks+1
	
	--# Reset ticks counter every 60 seconds (i.e. after 1 min)
	if ticks > 3601 then
		ticks = 1
		lastBulletTick = 1
	end

	--#OPTIMIZATION: make a local var with the same name as the global one, now that we won't be modifying it anymore but we'll read it quite often in the rest of the script / main loop
	local ticks=ticks

	--# === GAMEPLAY STATE ===
	if STATE == 1 then
		
		--# === OPTIMIZATION ===
		--# Make local vars with the same names as the global ones, then we'll copy back the values from local to global vars at the end of the main loop
		local playerX = playerX
		local playerY = playerY
		local scrollX = scrollX
		local scrollY = scrollY
		local playerAnim = playerAnim
		local playerFlipX = playerFlipX
		local screenshake = screenshake
		local foesTimer = foesTimer
		local lastBulletTick = lastBulletTick
	
			
		--# Local variable to check wether we can increase animation frame if player walks
		local animate = ticks % 5 == 0
		local shoot = ticks % 10 == 0
		local star = ticks % 10 == 0
		local moving = false
		
		-- right
		if btn(5) then
			moving = true
			if playerX >= 227 then
				playerX = 227
			else
				playerX = playerX + 3	
			end
			playerFlipX=nil
		end
		-- left
		if btn(4) then
			moving = true
			if playerX <= -3 then
				playerX = -3
			else
				playerX = playerX - 3
			end
			playerFlipX=1
		end
		-- up
		if btn(6) then
			moving = true
			if playerY <= -2 then
				playerY = -2
			else
				playerY = playerY - 3
			end
		end
  	-- down
		if btn(7) then
			moving = true
			if playerY >= 144 then
				playerY = 144
			else
				playerY = playerY + 3
			end
		end

		-- A -- player shoot
		if btn(0) then
			if ticks - lastBulletTick > 10 then
				spawnPlayerBullet()
				lastBulletTick = ticks
			end
		end

		-- L -- spawn enemy type 0
		if btn(8) then
			if ticks - lastBulletTick > 10 then
				spawnEnemy(0)
				lastBulletTick = ticks
			end
		end

		-- R -- spawn enemy type 1
		if btn(9) then
			if ticks - lastBulletTick > 10 then
				spawnEnemy(1)
				lastBulletTick = ticks
			end
		end

		-- select -- spawn enemy type 2
		if btn(3) then
			if ticks - lastBulletTick > 10 then
				spawnEnemy(2)
				lastBulletTick = ticks
			end
		end

		if moving then
			if animate then
				playerAnim=playerAnim+1
				if playerAnim > 4 then
					playerAnim=1
				end
			end
		else
			-- stand still
			playerAnim=1
		end

		if tileStars then
			-- scroll the stars
			scrollY = scrollY - 1
			scroll(3, scrollX, scrollY)
		else
			-- spawn star
			if star then
				spawnStar()
			end
			-- update star positions
			for k, v in pairs(stars) do
				stars[k].y = v.y - v.speedY
				stars[k].x = v.x - v.speedX
				-- cull stars that are off screen
				if stars[k].y > 160 then
					table.remove(stars, k)
				end
			end
		end
		

		-- update player bullet positions
		for k, v in pairs(playerBullets) do
			playerBullets[k].y = playerBullets[k].y - playerBullets[k].speedY
			-- cull player bullets that are off screen
			if playerBullets[k].y < -12 then
				table.remove(playerBullets, k)
			end
		end

		-- update enemy positions
		for k, v in pairs(enemies) do
			if v.type == 0 then
				enemies[k].y = v.y - v.speedY
				enemies[k].x = v.x - v.speedX
			elseif v.type == 1 then
				-- bounce off walls
				if (v.x >= (240 - 16) and v.speedX < 0) or (v.x <= 0 and v.speedX > 0) then
					enemies[k].speedX = v.speedX * -1
				end
				enemies[k].y = v.y - v.speedY
				enemies[k].x = v.x - v.speedX
			elseif v.type == 2 then
				-- every n ticks, reverse x direction, makes enemy move in zigzag pattern
				local mod = (ticks % 30)
				if mod == 0 then
					enemies[k].speedX	= v.speedX * -1
				end
				enemies[k].y = v.y - v.speedY
				enemies[k].x = v.x - (v.speedX * (mod / 20))
			end
			-- cull enemies that are off screen
			if enemies[k].y > 160 then
				table.remove(enemies, k)
			end
		end

		detectCollision()

		--# === SCREENSHAKE ===
		
		--# If we must apply screenshake
		if screenshake > 0 then
		
			--#Decrease screenshake counter
			screenshake = screenshake-1
			
			--# If we are still in screenshake mode, raise the ground, else put it back to normal position (it's hackjob to avoid using a modulo as we don't need an actual screenshake every 2 frames, but just a way to make the ground move a little after each meteor hitting ground)
			if screenshake > 0 then
				scroll(2, 0, 2)
			else 
				scroll(2, 0, 0)
			end	
		end
		
		--# === OPTIMIZATION === 
		--# Copy back the values from local to global vars with the same name at the end of the main loop (for gameplay only, other states are not so time critical so we didn't optimize them. And for gameover I actually use slowdown voluntarily for a more dramatic effect!)
		_G.playerX = playerX
		_G.playerY = playerY
		_G.scrollX = scrollX
		_G.scrollY = scrollY
		_G.playerAnim = playerAnim
		_G.playerFlipX = playerFlipX
		_G.screenshake = screenshake
		_G.foesTimer = foesTimer
		_G.lastBulletTick = lastBulletTick


	--# === GAME OVER STATE ===	
	elseif STATE == 2 then
	
		--#If the game over animation isn't finished
		if ticks_anim > 0 then
		
			--#Decrease countdown
			ticks_anim = ticks_anim-1
			
			--#Init : display load of meteor piece on the first frame
			if ticks_anim == 179 then
				
				--# For each foe - DONT'T optimize this loop (by using for i + locals instead of ipairs + global like we did for gameplay and rendering) as the slowdown produces a better effect on the game over screen!
				for i, obj  in ipairs(foes) do 
					
					--#Activate the foe
					obj.active=1
					
					--#Position it over the player
					obj.x=playerX+5-math.random(9)
					obj.y=playerY-5+math.random(7)
					
					--#And set its speed values
					obj.speedX=3-math.random(7)
					obj.speedY=-(2+math.random(4))
				end
				
				--#Stop the screenshake
				screenshake=0
				scroll(2, 0, 0)
			end
			
			--#Display Game over message
			if ticks_anim == 130 then
			
				--#Erase the top line of text overlay (where score is displayed ingame)
				--#For every column
				for i = 0,30,1 
				do 
					--#Manually put a "black" tile in the layer
					tile(0, i, 0, 1)
				end
			
				--#Display Game Over
				print("GAME OVER", 10, 4)
			end
			
			--#Fade out slowly 
			if ticks_anim < 120 and ticks_anim >= 20 then
				fade( (ticks_anim-20)/100, 0xFFFFFF, nil, 1)
			end
			
			--# When anim is finished, reset ticks so the blinking message starts immediatedly on the next frame
			if ticks_anim == 0 then
				ticks=29
			end

		--#Else the countdown is finished, so we can restart the game if needed
		else 
			--#Display blinking press button to start message
			j=ticks % 60
			if j == 30 then
				print("press button to restart", 4, 15)
			elseif j == 0 then
				--#erase the message (printing a "space" will leave a black square, this code put a transparent tile instead)
				for i = 4,26,1 do 
					tile(0, i, 15, 1)
				end
			end
		
			--#Restart game when button pressed
			if btnp(0) or btnp(1) then
				--#Restart the game! (using a fading handled by a separate state)
				STATE=3
				ticks_anim = 60
			end
		end	
		
		
		
		--#Animate the meteor pieces falling
		
		--#Compte gravity only once for all meteors
		local gravity = ticks % 7
		
		--# For each foe - DONT'T optimize this loop (by using for i + locals instead of ipairs + global like we did for gameplay and rendering) as the slowdown produces a better effect on the game over screen!
		for i, obj  in ipairs(foes) do 
		
			--#If the foe is active
			if obj.active == 1 then
			
				--# Move foe according to its speed
				obj.x=obj.x+obj.speedX
				obj.y=obj.y+obj.speedY
				
				--# Ohh, gravity
				if gravity == 0 then
					obj.speedY = obj.speedY+1;
				end
				
				--#If the meteor goes out of the screen
				if obj.y > 240 then
				
					--# Disable the meteor
					obj.active=0
					
					--# reset the meteor positions
					obj.x=math.random(224)
					obj.y=-16
					obj.speedY=0
					obj.speedX=0
				end	
				
			end
		end	
		
		
	--# === GAME (RE)START FADING STATE ===	
	elseif STATE == 3 then
	
		--#If the animation isn't finished
		if ticks_anim > 0 then
		
			--#Decrease countdown
			ticks_anim = ticks_anim-1
			
			--#Fade out slowly 
			if ticks_anim > 30 then
				fade( 1-((ticks_anim-30)/30), 0x000000, 1, 1)
			
			--#(re)set game
			elseif ticks_anim == 30 then
				init()	
				
			--#Fade in slowly 
			elseif ticks_anim > 0 then
				fade(  ticks_anim/30, 0x000000, 1, 1)
			
			--#Animation finished, start the game
			else 
				STATE=1
			end

		end
	
	
	--# === TITLE SCREEN STATE ===	
	elseif STATE == 0 then
	
		--#If the animation isn't finished
		if ticks_anim > 0 then
		
			--#Decrease countdown
			ticks_anim = ticks_anim-1
			
			--#Init : display title screen elements
			if ticks_anim == 59 then
				print("Customer", 11, 3)
				print("Profile", 11, 5)
				print("Shooter", 11, 7)
			end
			
			--#Fade in slowly 
			if ticks_anim >= 0 then
				fade( ticks_anim/60, 0x000000, 1, 1)
			end

		--#Else the countdown is finished, so we can start the game if needed
		else 
		
			--#Display blinking press button to start message
			j=ticks % 60
			if j == 30 then
				print("press A to start", 8, 11)
			elseif j == 0 then
				--#erase the message (printing a "space" will leave a black square, this code put a transparent tile instead)
				for i = 5,25,1 do 
					tile(0, i, 11, 1)
				end
			end
		
			--#Restart game when button pressed
			if btnp(0) or btnp(1) then
			
				--#Start the game! (using a fading handled by a separate state)
				STATE=3
				ticks_anim = 60
			end
		end	
		
	end	
	
end


--# ------------------------------------
--# --- RENDER SCREEN ----
--# ------------------------------------
--# MEMO: sprites are drawn from front to bottom in BPCore-Engine
function draw()
	--# === OPTIMIZATION ===
	--# Make local vars with the same names a the global one for faster access (no need to copy back values at the end of the function, as it only reads them)
	local playerX=playerX
	local playerY=playerY
	local playerAnim=playerAnim
	local playerFlipX=playerFlipX
	
	--#If we are in gameplay, display regular meteors
	if STATE == 1 then

		if not tileStars then
			-- render stars
			for k, v in pairs(stars) do
				-- tile(3, v.x, v.y, 63)
				if v.speedY == -2 then
					spr(9, v.x, v.y)
				else
					spr(8, v.x, v.y)
				end
			end
		end

		-- render player
		spr(playerAnim, playerX, playerY, playerFlipX)
	
		-- render player bullets
		for k, v in pairs(playerBullets) do
			spr(8, v.x, v.y)
		end

		-- render enemies
		for k, v in pairs(enemies) do
			if v.type == 0 then
				spr(0, v.x, v.y)
			elseif v.type == 1 then
				spr(5, v.x, v.y)
			elseif v.type == 2 then
				spr(6, v.x, v.y)
			end
		end
	end
	
	--# Then display Player
	spr(playerAnim, playerX, playerY, playerFlipX)
end

function drawScore()
	print("score:"..score, 0, 0)
end

function spawnStar()
	local speed = 2
	if math.random(0, 2) == 0 then
		speed = 1.5
	end
	table.insert(
		stars,
		{
			x = math.random(240),
		  y = -12,
		  speedX = 0,
			-- speedY = -2
		  speedY = -1 * speed
		}
	)
end

function spawnPlayerBullet()
	table.insert(
		playerBullets,
		{
			x = playerX - 2,
		  y = playerY - 8,
		  speedX = 0,
		  speedY = 2
		}
	)
end

function spawnEnemy(type)
	local spawnX = playerX
	local initSpeedX = 0
	local initSpeedY = -1
	local randRange10 =math.random(-10, 10)

	-- spawn at random x pos and move down screen at random angle
	if type == 0 then
		initX = math.random(240)
		initSpeedX = (randRange10 / 10)
	-- spawn in either top corner and move diagonally, bouncing off walls
	elseif type == 1 then
		if math.random(0, 1) == 0 then
			initX = 0
			initSpeedX = -1.8
		else
			initX = 240
			initSpeedX = 1.8
		end
		initSpeedY = -0.5 + (randRange10 / 15)
	-- move down screen in zig zag pattern
	elseif type == 2 then
		initX = math.random(20, 220)
		initSpeedX = (randRange10 / 3)
	end

	table.insert(
		enemies,
		{
			type = type,
			x = initX,
		  y = -12,
		  speedX = initSpeedX,
		  speedY = initSpeedY
		}
	)
end

function detectCollision()
	for ek, ev in pairs(enemies) do
		for bk, bv in pairs(playerBullets) do
			if colliding(ev.x, ev.y, 16, 16,  bv.x, bv.y + 12, 16, 16) then
				table.remove(enemies, ek)
				table.remove(playerBullets, bk)
				score = score + 10
				drawScore()
			end
		end
	end
end

-- https://love2d.org/forums/viewtopic.php?p=196465&sid=7893979c5233b13efed2f638e114ce87#p196465
function colliding(x1,y1,w1,h1, x2,y2,w2,h2)
	-- print(x1..","..y1.." -- "..x2..","..y2, 0, 19)
  return (
    x1 < x2+w2 and
    x2 < x1+w1 and
    y1 < y2+h2 and
    y2 < y1+h1
  )
end
--# Count how much RAM the whole LUA script is using (max 256kb)
-- print(tostring(collectgarbage("count")*1024), 0, 19)


--# ------------------------------------
--# ------- MAIN LOOP ---------
--# ------------------------------------

--#First, display the title screen (we are still with the screen faded off completely, so the "fade in" will be made by title screen state)
STATE=0
--#Define the duration for the title screen animation (fade in)
ticks_anim=60

--#Then, enter the endless loop of the program
while true do
	--#Update the game code (don't use the delta variable time as we don't need it for this game - every CPU cycle counts here!)
	update()
	--# Clear screen and waits for Vblank
	clear()
	--# Draw screen (make the spr and tile calls)
	draw()
	--# Process the spr and tile calls to actually update the display
	display()	
end

