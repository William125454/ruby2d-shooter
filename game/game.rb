require "ruby2d"

set width: 1280, height: 720
set background: "black"

PLAYER_SIZE = 45
PLAYER_START_X = 400
PLAYER_START_Y = 300
PLAYER_SPEED = 8
PLAYER_DASH_SPEED = 30
PLAYER_DASH_DURATION = 5
PLAYER_DASH_COOLDOWN = 10
ENEMY_SIZE = 25
ENEMY_SPEED = 2
ENEMY_MAX_SPEED = 6
ENEMY_HP = 100
ENEMY_ATTACK_DISTANCE = 55
ENEMY_BACK_OFF_DISTANCE = 35
ENEMY_STRAFE_FORCE = 0.35
ENEMY_SEPARATION_DISTANCE = 35
ENEMY_SEPARATION_FORCE = 1.5

START_ENEMY_COUNT = 6
ENEMIES_ADDED_PER_WAVE = 2
SCORE_PER_KILL = 100

DAMAGE_PER_SECOND = 15
PROJECTILE_DAMAGE = 50

HUD_TEXT_SIZE = 25
HUD_Z = 100

start_title = Text.new(
  "TOP DOWN SHOOTER",
  x: Window.width / 2 - 220,
  y: Window.height / 2 - 130,
  size: 50,
  color: "white",
  z: HUD_Z 
)

start_text = Text.new(
  "Press ENTER to start",
  x: Window.width / 2 - 170,
  y: Window.height / 2 - 50,
  size: 30,
  color: "white",
  z: HUD_Z
)

controls_text = Text.new(
  "WASD = move   SPACE = shoot   SHIFT = dash",
  x: Window.width / 2 - 280,
  y: Window.height / 2,
  size: 24,
  color: "white",
  z: HUD_Z
)

player = Image.new(
  File.join(__dir__, "soldier1_gun.png"),
  x: PLAYER_START_X,
  y: PLAYER_START_Y,
  width: PLAYER_SIZE,
  height: PLAYER_SIZE
)

keys = {}
projectiles = []
dash_time = 0
dash_cooldown = 0
dash_x = 0
dash_y = 0

hp = 100

hp_text = Text.new(
  "HP: #{hp}",
  x: 20,
  y: 15,
  size: HUD_TEXT_SIZE,
  color: "white", 
  z: HUD_Z
)

walls = [
  Rectangle.new(
    x: 100,
    y: 200,
    width: 100,
    height: 35,
    color: "gray"
  ),

  Rectangle.new(
  x: 350,
  y: 450,
  width: 75,
  height: 250,
  color: "gray"
  ),

  Rectangle.new(
    x: 800,
    y: 150,
    width: 50,
    height: 200,
    color: "gray"
  )
  
]

score = 0
wave = 1

score_text = Text.new(
  "Score: #{score}",
  x: 20,
  y: 50,
  size: HUD_TEXT_SIZE,
  color: "white",
  z: HUD_Z
)

wave_text = Text.new(
  "Wave: #{wave}",
  x: 20,
  y: 85,
  size: HUD_TEXT_SIZE,
  color: "white",
  z: HUD_Z
)

def enemy_count_for_wave(wave)
  START_ENEMY_COUNT + (wave - 1) * ENEMIES_ADDED_PER_WAVE
end

def enemy_spawn_position
  case rand(4)
  when 0
    [rand(0..(Window.width - ENEMY_SIZE)).to_f, -ENEMY_SIZE.to_f]
  when 1
    [Window.width.to_f, rand(0..(Window.height - ENEMY_SIZE)).to_f]
  when 2
    [rand(0..(Window.width - ENEMY_SIZE)).to_f, Window.height.to_f]
  else
    [-ENEMY_SIZE.to_f, rand(0..(Window.height - ENEMY_SIZE)).to_f]
  end
end

def spawn_enemy(wave)
  x, y = enemy_spawn_position

  {
    x: x,
    y: y,
    hp: ENEMY_HP + (wave - 1) * 25,
    speed: [ENEMY_SPEED + (wave - 1) * 0.5, ENEMY_MAX_SPEED].min,
    strafe_direction: [-1, 1].sample,
    shape: Image.new(
      File.join(__dir__, "zoimbie1_stand.png"),
      x: x,
      y: y,
      width: ENEMY_SIZE,
      height: ENEMY_SIZE
    )
  }
end

def spawn_wave(enemies, wave)
  enemy_count_for_wave(wave).times do
    enemies << spawn_enemy(wave)
  end
end

def clear_enemies(enemies)
  enemies.each do |enemy|
    enemy[:shape].remove
  end

  enemies.clear
end

def clear_projectiles(projectiles)
  projectiles.each do |projectile|
    projectile.remove
  end

  projectiles.clear
end

def update_hud(hp_text, score_text, wave_text, hp, score, wave)
  hp_text.text = "HP: #{hp.round}"
  score_text.text = "Score: #{score}"
  wave_text.text = "Wave: #{wave}"
end

def clamp_player_to_window(player)
  player.x = [[player.x, 0].max, Window.width - PLAYER_SIZE].min
  player.y = [[player.y, 0].max, Window.height - PLAYER_SIZE].min
end

def rectangles_touch?(x1, y1, w1, h1, x2, y2, w2, h2)
  x1 < x2 + w2 &&
    x1 + w1 > x2 &&
    y1 < y2 + h2 &&
    y1 + h1 > y2
end

def player_touching_wall?(player, walls)
  walls.any? do |wall|
    rectangles_touch?(
      player.x, player.y, PLAYER_SIZE, PLAYER_SIZE,
      wall.x, wall.y, wall.width, wall.height
    )
  end
end

def enemy_touching_wall?(enemy, walls)
  walls.any? do |wall|
    rectangles_touch?(
      enemy[:x], enemy[:y], ENEMY_SIZE, ENEMY_SIZE,
      wall.x, wall.y, wall.width, wall.height
    )
  end
end

def clamp_enemy_to_window(enemy)
  enemy[:x] = [[enemy[:x], 0].max, Window.width - ENEMY_SIZE].min
  enemy[:y] = [[enemy[:y], 0].max, Window.height - ENEMY_SIZE].min
end

def move_enemy_by(enemy, x_amount, y_amount, walls)
  old_enemy_x = enemy[:x]
  old_enemy_y = enemy[:y]

  enemy[:x] += x_amount
  enemy[:y] += y_amount
  clamp_enemy_to_window(enemy)

  return true unless enemy_touching_wall?(enemy, walls)

  enemy[:x] = old_enemy_x
  enemy[:y] = old_enemy_y
  false
end

def move_enemy(enemy, enemies, player, walls)
  enemy_center_x = enemy[:x] + ENEMY_SIZE / 2
  enemy_center_y = enemy[:y] + ENEMY_SIZE / 2
  player_center_x = player.x + PLAYER_SIZE / 2
  player_center_y = player.y + PLAYER_SIZE / 2

  to_player_x = player_center_x - enemy_center_x
  to_player_y = player_center_y - enemy_center_y
  player_distance = Math.sqrt(to_player_x * to_player_x + to_player_y * to_player_y)

  if player_distance > 0
    to_player_x /= player_distance
    to_player_y /= player_distance
  end

  chase_x = 0
  chase_y = 0

  if player_distance > ENEMY_ATTACK_DISTANCE
    chase_x = to_player_x
    chase_y = to_player_y
  elsif player_distance < ENEMY_BACK_OFF_DISTANCE
    chase_x = -to_player_x
    chase_y = -to_player_y
  end

  strafe_x = -to_player_y * enemy[:strafe_direction] * ENEMY_STRAFE_FORCE
  strafe_y = to_player_x * enemy[:strafe_direction] * ENEMY_STRAFE_FORCE

  separation_x = 0
  separation_y = 0

  enemies.each do |other_enemy|
    next if enemy == other_enemy

    separate_x = enemy[:x] - other_enemy[:x]
    separate_y = enemy[:y] - other_enemy[:y]
    separate_distance = Math.sqrt(separate_x * separate_x + separate_y * separate_y)

    if separate_distance > 0 && separate_distance < ENEMY_SEPARATION_DISTANCE
      push_strength = (ENEMY_SEPARATION_DISTANCE - separate_distance) / ENEMY_SEPARATION_DISTANCE
      separation_x += (separate_x / separate_distance) * push_strength
      separation_y += (separate_y / separate_distance) * push_strength
    end
  end

  move_x = chase_x + strafe_x + separation_x * ENEMY_SEPARATION_FORCE
  move_y = chase_y + strafe_y + separation_y * ENEMY_SEPARATION_FORCE
  move_distance = Math.sqrt(move_x * move_x + move_y * move_y)

  if move_distance > 0
    speed = enemy[:speed]
    speed *= 0.6 if player_distance < ENEMY_ATTACK_DISTANCE

    step_x = (move_x / move_distance) * speed
    step_y = (move_y / move_distance) * speed

    unless move_enemy_by(enemy, step_x, step_y, walls)
      move_enemy_by(enemy, step_x, 0, walls) ||
        move_enemy_by(enemy, 0, step_y, walls)
    end
  end

  enemy[:shape].x = enemy[:x]
  enemy[:shape].y = enemy[:y]

  dx = player_center_x - (enemy[:x] + ENEMY_SIZE / 2)
  dy = player_center_y - (enemy[:y] + ENEMY_SIZE / 2)
  Math.sqrt(dx * dx + dy * dy)
end

enemies = []

game_started = false
game_over = false

game_over_text = Text.new(
  "",
  x: 250,
  y: 250,
  size: 50,
  color: "white"
)

restart_text = Text.new(
  "",
  x: 250,
  y: 320,
  size: 30,
  color: "white"
)

class Projectile
  SPEED = 15
  WIDTH = 14
  HEIGHT = 14

  def initialize(x, y, angle)
    @shape = Rectangle.new(
      x: x,
      y: y,
      width: WIDTH,
      height: HEIGHT,
      color: "yellow"
    )

    radians = angle * Math::PI / 180
    @x_velocity = Math.sin(radians) * SPEED
    @y_velocity = -Math.cos(radians) * SPEED
  end

  def move
    @shape.x += @x_velocity
    @shape.y += @y_velocity
  end

  def hit?(target_x, target_y, target_size)
    @shape.x < target_x + target_size &&
      @shape.x + WIDTH > target_x &&
      @shape.y < target_y + target_size &&
      @shape.y + HEIGHT > target_y
  end

  def outside_window?
    @shape.x < -WIDTH ||
      @shape.x > Window.width ||
      @shape.y < -HEIGHT ||
      @shape.y > Window.height
  end

  def remove
    @shape.remove
  end
end

on :key_down do |event|
  keys[event.key] = true
  close if event.key =="escape"
  if !game_started && event.key == "return"
    game_started = true

    start_title.text = ""
    start_text.text = ""
    controls_text.text = ""

    spawn_wave(enemies, wave)
    update_hud(hp_text, score_text, wave_text, hp, score, wave)
  end
    
  if game_over && event.key == "return"
    hp = 100
    score = 0
    wave = 1
    dash_time = 0
    dash_cooldown = 0
    player.x = PLAYER_START_X
    player.y = PLAYER_START_Y

    clear_enemies(enemies)
    clear_projectiles(projectiles)

    spawn_wave(enemies, wave)
            
    game_over = false
    game_over_text.text = ""
    restart_text.text = ""
    update_hud(hp_text, score_text, wave_text, hp, score, wave)
  end

  if ["left shift", "right shift", "shift"].include?(event.key) && !game_over && dash_cooldown <= 0
    dash_x = 0
    dash_y = 0

    dash_y -= 1 if keys["w"]
    dash_y += 1 if keys["s"]
    dash_x -= 1 if keys["a"]
    dash_x += 1 if keys["d"]

    dash_distance = Math.sqrt(dash_x * dash_x + dash_y * dash_y)
    if dash_distance > 0
      dash_x /= dash_distance
      dash_y /= dash_distance

      dash_time = PLAYER_DASH_DURATION
      dash_cooldown = PLAYER_DASH_COOLDOWN
    end
    
  end

  if event.key == "space" && !game_over
    player_center_x = player.x + PLAYER_SIZE / 2
    player_center_y = player.y + PLAYER_SIZE / 2

    dx = Window.mouse_x - player_center_x
    dy = Window.mouse_y - player_center_y

    angle = Math.atan2(dx, -dy) * 180 / Math::PI
    player.rotate = angle - 90

    projectiles << Projectile.new(
      player_center_x - 5,
      player_center_y - 5,
      angle
    )
  end
    

end

on :key_up do |event|
  keys[event.key] = false
end

update do
  next if game_over || !game_started

  projectiles.each do |projectile|
    projectile.move
  end

  projectiles_to_remove = []
  enemies_to_remove = []

  projectiles.each do |projectile|
    enemies.each do |enemy|
      if projectile.hit?(enemy[:x], enemy[:y], ENEMY_SIZE)
        enemy[:hp] -= PROJECTILE_DAMAGE
        projectiles_to_remove << projectile

        if enemy[:hp] <= 0
          score += SCORE_PER_KILL
          enemies_to_remove << enemy
        end

        break
      end
    end
  end

  projectiles_to_remove.each do |projectile|
    projectile.remove
    projectiles.delete(projectile)
  end

  enemies_to_remove.each do |enemy|
    enemy[:shape].remove
    enemies.delete(enemy)
  end

  if enemies.empty? && !game_over
    wave += 1
    spawn_wave(enemies, wave)
  end

  dash_cooldown -= 1 if dash_cooldown > 0

  old_player_x = player.x
  old_player_y = player.y

  if dash_time > 0
    player.x += dash_x * PLAYER_DASH_SPEED
    player.y += dash_y * PLAYER_DASH_SPEED
    dash_time -= 1
  else
    player.y -= PLAYER_SPEED if keys["w"]
    player.y += PLAYER_SPEED if keys["s"]
    player.x -= PLAYER_SPEED if keys["a"]
    player.x += PLAYER_SPEED if keys["d"]
  end

  clamp_player_to_window(player)

  if player_touching_wall?(player, walls)
    player.x = old_player_x
    player.y = old_player_y
  end

  enemies.each do |enemy|
    distance = move_enemy(enemy, enemies, player, walls)

    if distance < ENEMY_ATTACK_DISTANCE
      hp -= DAMAGE_PER_SECOND / 60.0
      hp = 0 if hp < 0
    end
  end

  if hp <= 0
    hp = 0
    game_over = true
    game_over_text.text = "Game OVER YOU LOSE!"
    restart_text.text = "Press ENTER to play again"
  end

  update_hud(hp_text, score_text, wave_text, hp, score, wave)
end

show