-- gba screen res 240x160

player = {
	x = 0,
	y = -16,
	animState = 0,
}

bgScroll = {
	x = 0,
	y = 0
}

playerBullets = {}
lastBulletTick = 0
lastPlayerHitTick = 0

enemies = {}
bosses = {}

-- 0 = title screen
-- 1 = gameplay
-- 2 = gameover
-- 3 = screen fading
gameState = 0
level = 0
ticks = 0
score = 0
lives = 3
ticks_anim = 0

levelNames = {
	[0] = "TIM",
	[1] = "TOM",
	[2] = "CODY"
}
enemyNames = {
	-- [enemyType:int] = enemyName:string
	[0] = "lead-captured",
	[1] = "agent-selected",
	[2] = "engagement-finalized"
}
levels = {
	[0] = {
		-- [tickNumber:int] = enemyType:int
		[100] = 0,
		[150] = 1,
		[200] = 2,
		[250] = 2,
		[300] = 0,
		[350] = -1
	},
	[1] = {
		[100] = 0,
		[150] = 1,
		[200] = 2,
		[250] = 2,
		[300] = 0,
		[350] = -1
	},
	[2] = {
		[100] = 0,
		[150] = 1,
		[200] = 2,
		[250] = 2,
		[300] = 0,
		[350] = -1
	}
}

--# Hide the screen
fade(1)

--# Load tiles data for each layer
txtr(0, "overlay.bmp")
txtr(1, "tiles.bmp")
txtr(2, "tiles.bmp")


-- black out screen
-- fill enough vertical lines for a seamless vertical scroll
for i = 0, 31, 1 do 
	for j = 0, 29, 1 do 
		tile(3, j, i, 62) -- black tile
	end
end

-- randomly place stars
-- gba will loop the scrolling tile layer for the appearance of endless stars passing by as the ship moves
for i = 0, 25, 1 do
	tile(3, math.random(30), math.random(30), 62+math.random(9)) -- random star tile
end

--#Reorder the layer priority so the sprites are displayed OVER the overlay (other layers are kept to their default values)
priority(0, 2, 3, 3)

--# ----------------------------------
--# ------- GAME INIT --------
--# ----------------------------------
function init()
	-- load game sprites
	-- txtr(4, "sprites.bmp")
	--#Init gameplay vars
	ticks = 0
	lastBulletTick = 0
	score = 0
	enemies = {}
	bosses = {}
	lives = 3
	
	player.x = 112
	player.y = 130
	player.animState = 1
	
	-- blank screen
	for i = 0, 19, 1 do 
		for j = 0, 30, 1 do 
			tile(0, j, i, 1)
		end
	end

	-- draw initial score
	print("score:"..score, 0, 0)	
	music("music1.raw", 0)
end

function update()
	ticks = ticks+1

	if ticks == 1 then
		lastBulletTick = 1
	elseif ticks > 3601 then -- reset every 60 seconds (assuming 60fps performance)
		ticks = 1
		lastBulletTick = 1
	end

	--#OPTIMIZATION: make a local var with the same name as the global one, now that we won't be modifying it anymore but we'll read it quite often in the rest of the script / main loop
	local ticks=ticks

	if gameState == 1 then
		--# Make local vars with the same names as the global ones, then we'll copy back the values from local to global vars at the end of the main loop
		local player = player
		local bgScroll = bgScroll
		local lastBulletTick = lastBulletTick
		local bosses = bosses
	
		--# Local variable to check wether we can increase animation frame if player walks
		local animate = ticks % 5 == 0
		local shoot = ticks % 10 == 0
		local star = ticks % 10 == 0
		local moving = false

		-- left
		if btn(4) then
			moving = true
			if player.x <= -3 then
				player.x = -3
			else
				player.x = player.x - 3
			end
		end
		-- right
		if btn(5) then
			moving = true
			if player.x >= 227 then
				player.x = 227
			else
				player.x = player.x + 3	
			end
		end
		-- up
		if btn(6) then
			moving = true
			if player.y <= -2 then
				player.y = -2
			else
				player.y = player.y - 3
			end
		end
  	-- down
		if btn(7) then
			moving = true
			if player.y >= 144 then
				player.y = 144
			else
				player.y = player.y + 3
			end
		end
		-- A -- player shoot
		if btn(0) then
			if ticks - lastBulletTick > 10 then
				spawnPlayerBullet()
				lastBulletTick = ticks
			end
		end

		-- -- L -- spawn enemy type 0
		-- if btn(8) then
		-- 	if ticks - lastBulletTick > 10 then
		-- 		spawnEnemy(0)
		-- 		lastBulletTick = ticks
		-- 	end
		-- end
		-- -- R -- spawn enemy type 1
		-- if btn(9) then
		-- 	if ticks - lastBulletTick > 10 then
		-- 		spawnEnemy(1)
		-- 		lastBulletTick = ticks
		-- 	end
		-- end
		-- -- select -- spawn enemy type 2
		-- if btn(3) then
		-- 	if ticks - lastBulletTick > 10 then
		-- 		spawnEnemy(2)
		-- 		lastBulletTick = ticks
		-- 	end
		-- end
		-- -- start
		-- if btn(2) then
		-- end

		-- animation
		if moving then
			if animate then
				player.animState = player.animState + 1
				if player.animState > 4 then
					player.animState = 1
				end
			end
		else
			-- not moving
			player.animState = 1
		end

		-- spawn enemies according to level script
		if levels[level][ticks] then
			if levels[level][ticks] == -1 then
				spawnBoss(level)
				updateStatus("DEFEAT "..levelNames[level].."!!!")
			else
				spawnEnemy(levels[level][ticks])
				updateStatus(levelNames[level]..": "..enemyNames[levels[level][ticks]])
			end
		end

		-- scroll the star layer
		bgScroll.y = bgScroll.y - 1
		scroll(3, bgScroll.x, bgScroll.y)

			-- update player bullet positions
		for k, v in pairs(playerBullets) do
			playerBullets[k].y = playerBullets[k].y - playerBullets[k].speedY
			-- cull player bullets that are off screen
			if playerBullets[k].y < -12 then
				table.remove(playerBullets, k)
			end
		end

		-- enemy movement
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

		-- boss movement
		local mod40 = (ticks % 40)
		local mod80 = (ticks % 40)
		for k, boss in pairs(bosses) do
			if boss.level == 0 then
				-- wobble at top of screen
				if mod40 == 0 then
					boss.speedX	= boss.speedX * -1
					spawnEnemy(0, boss.x, boss.y + 20)
				end
				boss.y = boss.y - boss.speedY
				boss.x = boss.x - (boss.speedX * (mod40 / 20))
			elseif boss.level == 1 then
				-- bounce around screen
				if mod80 == 0 then
					spawnEnemy(1, boss.x, boss.y + 20)
				end
				if (boss.x >= (240 - 32) and boss.speedX < 0) or (boss.x <= 0 and boss.speedX > 0) then
					boss.speedX = boss.speedX * -1
				end
				if (boss.y >= (160 - 32) and boss.speedY < 0) or (boss.y <= 0 and boss.speedY > 0) then
					boss.speedY = boss.speedY * -1
				end
				boss.y = boss.y - boss.speedY
				boss.x = boss.x - boss.speedX
			elseif boss.level == 2 then
				-- combo of both movement types
				if mod40 == 0 then
					boss.speedX	= boss.speedX * -1
					spawnEnemy(2, boss.x, boss.y + 20)
				end
				if (boss.x >= (240 - 32) and boss.speedX < 0) or (boss.x <= 0 and boss.speedX > 0) then
					boss.speedX = boss.speedX * -1
				end
				if (boss.y >= (160 - 32) and boss.speedY < 0) or (boss.y <= 0 and boss.speedY > 0) then
					boss.speedY = boss.speedY * -1
				end
				boss.y = boss.y - (boss.speedY * (mod40 / 20))
				boss.x = boss.x - (boss.speedX * (mod40 / 20))
			end
		end

		detectCollision()
		
		--# === OPTIMIZATION === 
		--# Copy back the values from local to global vars with the same name at the end of the main loop (for gameplay only, other states are not so time critical so we didn't optimize them. And for gameover I actually use slowdown voluntarily for a more dramatic effect!)
		_G.player = player
		_G.bgScroll = bgScroll
		_G.lastBulletTick = lastBulletTick
		_G.bosses = bosses
	-- game over
	elseif gameState == 2 then
	
		--#If the game over animation isn't finished
		if ticks_anim > 0 then
		
			--#Decrease countdown
			ticks_anim = ticks_anim-1

			--#Fade out slowly 
			if ticks_anim < 120 and ticks_anim >= 20 then
				fade((ticks_anim - 20) / 100, 0xFFFFFF, nil, 1)
			end
			
			--# When anim is finished, reset ticks so the blinking message starts immediatedly on the next frame
			if ticks_anim == 0 then
				ticks = 29
			end

		--#Else the countdown is finished, so we can restart the game if needed
		else 
			--#Display blinking press button to start message
			j=ticks % 60
			if j == 30 then
				print("Don't forget to vote and", 3, 13)
				print("post high score in #codymullet", 0, 14)
				print("Press B to restart", 5, 15)
			elseif j == 0 then
				--#erase the message (printing a "space" will leave a black square, this code put a transparent tile instead)
				for i = 4,26,1 do 
					tile(0, i, 15, 1)
				end
			end
		
			-- B pressed, go to fade in state which eventually takes us to gameplay state
			if btnp(1) then
				gameState = 3
				ticks_anim = 60
			end
		end	
	-- fading
	elseif gameState == 3 then
	
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
				gameState = 1
				level = 0
			end

		end
	
	
	--# === TITLE SCREEN gameState ===	
	elseif gameState == 0 then
	
		--#If the animation isn't finished
		if ticks_anim > 0 then
			drawTimTomCody(10, 10)
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
			drawTimTomCody(10, 10)
		
			--#Display blinking press button to start message
			j=ticks % 60
			if j == 30 then
				print("Press A to start", 8, 11)
			elseif j == 0 then
				for i = 5, 25, 1 do 
					tile(0, i, 11, 1)
				end
			end
		
			--#Restart game when button pressed
			if btnp(0) or btnp(1) then
				gameState = 3
				ticks_anim = 60
				-- load game sprites after done rendering timtomcody
				txtr(4, "sprites.bmp")
			end
		end	
		
	end	
	
end

function drawBigSprites(name, x, y)
	txtr(4, name)
	for i = 0, 15, 1 do
		yPlus = 0
		if i < 4 then
			yPlus = 0
		elseif i < 8 then
			yPlus = 16 
		elseif i < 12 then
			yPlus = 32
		elseif i < 16 then
			yPlus = 48
		end
		spr(i, x + ((i % 4) * 16), y + yPlus)
	end
end

function drawTimTomCody(x, y)
	drawBigSprites("timtomcodysprites.bmp", x, y)
end

function draw()
	--# === OPTIMIZATION ===
	--# Make local vars with the same names a the global one for faster access (no need to copy back values at the end of the function, as it only reads them)
	local player = player
	local lives = lives
	local playerBullets = playerBullets
	local enemies = enemies
	local bosses = bosses
	
	-- gameplay
	if gameState == 1 then

		-- render player lives
		for i = 0, lives - 1, 1 do
			spr(1, 222 - (18 * i), 2, nil)
		end

		-- render player
		spr(player.animState, player.x, player.y)
	
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

		-- render boss
		for k, boss in pairs(bosses) do
			spr(boss.spriteIndex + 0, boss.x, boss.y);       spr(boss.spriteIndex + 1, boss.x + 16, boss.y)
			spr(boss.spriteIndex + 2, boss.x, boss.y + 16);  spr(boss.spriteIndex + 3, boss.x + 16, boss.y + 16)
		end
	end
end

function drawScore()
	print("score:"..score, 0, 0)
end

function spawnPlayerBullet()
	table.insert(
		playerBullets,
		{
			x = player.x,
		  y = player.y - 8,
		  speedX = 0,
		  speedY = 2
		}
	)
end

function spawnEnemy(type, overrideX, overrideY)
	local initSpeedX = 0
	local initSpeedY = -1
	local initX = 0
	local initY = 0
	local randRange10 = math.random(-10, 10)
	local randRangeScreenWidth = math.random(20, 220)

	-- spawn at random x pos and move down screen at random angle
	if type == 0 then
		initX = randRangeScreenWidth
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
		initSpeedY = -1 - (math.random(0, 10) / 10)
	-- move down screen in zig zag pattern
	elseif type == 2 then
		initX = randRangeScreenWidth
		initSpeedX = (randRange10 / 3)
	end

	local finalX = initX
	local finalY = initY
	if overrideX then
		finalX = overrideX
	end
	if overrideY then
		finalY = overrideY
	end

	table.insert(
		enemies,
		{
			type = type,
			x = finalX,
		  y = finalY,
		  speedX = initSpeedX,
		  speedY = initSpeedY
		}
	)
end

function spawnBoss(level)
	local randRange10 =math.random(-10, 10)

	local config = {
		[0] = {
			spriteIndex = 10,
			x = 120,
			y = 16,
			speedX = 4,
			speedY = 0,
			hp = 500
		},
		[1] = {
			spriteIndex = 14,
			x = math.random(20, 220),
			y = 8,
			speedX = 1.5,
			speedY = -4,
			hp = 600
		},
		[2] = {
			spriteIndex = 18,
			x = 130,
			y = 8,
			speedX = 3,
			speedY = -2,
			hp = 700
		}
	}

	table.insert(
		bosses, 
		{
			level = level,
			spriteIndex = config[level].spriteIndex,
			x = config[level].x,
			y = config[level].y,
			speedX = config[level].speedX,
			speedY = config[level].speedY,
			hp = config[level].hp
		}
	)
end

function bossHit()
	for k, v in pairs(bosses) do
		score = score + 10 -- 10 points per hit
		v.hp = v.hp - 50 -- 50 hp loss per hit
		if v.hp <= 0 then -- boss defeated
			table.remove(bosses, k)
			ticks = 0
			score = score + (50 * (level + 1)) -- 50, 100, 150 points for each kill
			if level < 2 then
				updateStatus(levelNames[level].." DEFEATED!!!")
				level = level + 1
			else
				gameOver(true)
			end
		end
	end
end

function playerHit()
	sound("sfx_crash.raw")
	lastPlayerHitTick = ticks
	lives = lives - 1
	if lives == 0 then
		gameOver(false)
	end
end

function gameOver(success)
	local face = ":("
	if success then
		face = ":)"
	end
	updateStatus("GAME OVER "..face)
	gameState = 2
end

function updateStatus(str)
	blankStatusLine()
	print(str, 0, 19)
end

function blankStatusLine()
	for i = 0, 29, 1 do
		tile(0, i, 19, 1)
	end
end

function detectCollision()
	-- boss collisions
	for ek, ev in pairs(bosses) do
		-- check player collision (enemy collides with boss)
		if (ticks - lastPlayerHitTick) > 30 then
			if colliding(ev.x + 10, ev.y + 8, 7, 20,  player.x, player.y, 16, 16) then
					playerHit()
			end
		end
		-- check boss bullet collision (boss gets shot)
		for bk, bv in pairs(playerBullets) do
			if colliding(ev.x + 10, ev.y + 8, 7, 20,  bv.x, bv.y + 12, 16, 16) then
				table.remove(playerBullets, bk)
				bossHit()
				drawScore()
			end
		end
	end
	-- regular enemy collisions
	for ek, ev in pairs(enemies) do
		-- check player collision (enemy collides with player)
		if colliding(ev.x, ev.y, 16, 16,  player.x, player.y + 12, 16, 16) then
				table.remove(enemies, ek)
				playerHit()
		end
		-- check player bullet collision (enemy gets shot)
		for bk, bv in pairs(playerBullets) do
			if colliding(ev.x, ev.y, 16, 16,  bv.x, bv.y + 12, 16, 16) then
				table.remove(enemies, ek)
				table.remove(playerBullets, bk)
				score = score + 10 -- 10 points per enemy hit
				drawScore()
			end
		end
	end
end

-- https://love2d.org/forums/viewtopic.php?p=196465&sid=7893979c5233b13efed2f638e114ce87#p196465
function colliding(x1,y1,w1,h1, x2,y2,w2,h2)
  return (
    x1 < x2+w2 and
    x2 < x1+w1 and
    y1 < y2+h2 and
    y2 < y1+h1
  )
end
--# Count how much RAM the whole LUA script is using (max 256kb)
-- print(tostring(collectgarbage("count")*1024), 0, 19)

gameState=0
--#Define the duration for the title screen animation (fade in)
ticks_anim=60

while true do
	update()
	clear()
	draw()
	display()	
end

