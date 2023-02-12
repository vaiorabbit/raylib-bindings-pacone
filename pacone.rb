require 'raylib'
include Raylib

####################################################################################################

class Game
  attr_reader :high_score, :configs, :current_score, :state_timer

  STATES = [:Ready, :Playing, :GameOver]
  DIR_R = 1.0
  DIR_L = -1.0

  StageConfig = Struct.new(:screen_width, :screen_height, :dot_count, keyword_init: true)

  STATE_READY_DURATION = 2.0

  def initialize
    @configs = {
      :stage_small  => StageConfig.new(screen_width:  720, screen_height: 360, dot_count: 10),
      :stage_normal => StageConfig.new(screen_width: 1280, screen_height: 480, dot_count: 20),
      :stage_large  => StageConfig.new(screen_width: 1920, screen_height: 720, dot_count: 40),
    }
    reset
  end

  def reset(keep_high_score: false)
    @state = :Ready
    @current_score = 0
    @high_score = 0 unless keep_high_score
    @state_timer = STATE_READY_DURATION
  end

  def update(dt)
    case @state
    when :Ready
      @state_timer -= dt
      if @state_timer < 0
        @state_timer = 0.0
        @state = :Playing
      end
    end
  end

  def set_state(new_state)
    raise ArgumentError unless STATES.include? new_state
    @state = new_state
  end
  private :set_state

  def finish = set_state(:GameOver)

  def ready? = @state == :Ready

  def game_over? = @state == :GameOver

  def current_score=(new_score)
    @current_score = new_score
    @high_score = @current_score if @current_score > @high_score
  end
end

####################################################################################################

class Stage
  attr_reader :width, :height, :center
  attr_accessor :offset

  def initialize(width, height)
    @width = width
    @height = height
    @center = Vector2.create(@width * 0.5, @height * 0.5)
    @offset = Vector2.create
  end

  def render
    DrawRectangle(0.0, @center.y - @height * 0.5 + @offset.y - 80.0,  @width, 10.0, DARKBLUE)
    DrawRectangle(0.0, @center.y - @height * 0.5 + @offset.y - 100.0, @width, 10.0, DARKBLUE)
    DrawRectangle(0.0, @center.y - @height * 0.5 + @offset.y + 80.0,  @width, 10.0, DARKBLUE)
    DrawRectangle(0.0, @center.y - @height * 0.5 + @offset.y + 100.0, @width, 10.0, DARKBLUE)
  end
end

####################################################################################################

class Dot
  attr_accessor :pos
  attr_reader :radius, :powerup

  SCORE_NORMAL = 10
  SCORE_POWERUP = 50

  RADIUS_NORMAL = 8.0
  RADIUS_POWERUP = 24.0

  def initialize
    @pos = Vector2.create
    @size = Vector2.create
    reset
  end

  def reset(powerup_on: false)
    @powerup = powerup_on
    @radius = powerup_on ? RADIUS_POWERUP : RADIUS_NORMAL
    @size.set(@radius, @radius)
    @active = true
  end

  def eaten? = !@active

  def hide = @active = false

  def score = @powerup ? SCORE_POWERUP : SCORE_NORMAL

  def render
    return unless @active
    if @powerup
      DrawCircle(@pos.x + @radius * 0.5 - RADIUS_NORMAL, @pos.y - @radius * 0.25 + RADIUS_NORMAL, @radius, BEIGE)
    else
      DrawRectangleV(@pos, @size, BEIGE)
    end
  end
end

####################################################################################################

class Enemy
  attr_accessor :pos
  attr_reader :hit_radius

  STATES = [:Alive, :Knockedout, :Stop]

  SCORE_KNOCKEDOUT = 200

  SPEED_NORMAL = 440.0
  SPEED_PANIC = SPEED_NORMAL * 0.25
  PANIC_DURATION = 3.0
  KNOCKEDOUT_DURATION = 1.5

  HIT_RADIUS = 40.0

  def initialize
    @pos = Vector2.create
    @anim_leg_timer = 0.0
    @panic = false
    @hit_radius = HIT_RADIUS
    reset
  end

  def reset
    @pos.set(0.0, 0.0)
    @dir = Game::DIR_R
    @anim_leg_timer = 0.0
    @anim_knockedout_timer = 0.0
    @panic_timer = 0.0
    @state = :Alive
  end

  def score = SCORE_KNOCKEDOUT

  def set_state(new_state)
    raise ArgumentError unless STATES.include? new_state
    @state = new_state
  end
  private :set_state

  def finish = set_state(:Stop)

  def knockout
    @anim_knockedout_timer = KNOCKEDOUT_DURATION
    set_state(:Knockedout)
  end

  def knockedout? = @state == :Knockedout

  def start_panic = @panic_timer = PANIC_DURATION

  def panic? = @panic_timer > 0.0

  def speed
    case @state
    when :Alive
      panic? ? SPEED_PANIC : SPEED_NORMAL
    when :Knockedout
      (2000.0 + (rand(2000) - 1000)) * (@anim_knockedout_timer ** 2)
    else
      0.0
    end
  end

  def run_ai(player_x:, stage_width:)
    return unless @state == :Alive
    dist_r = player_x - @pos.x
    dist_r += stage_width if dist_r.negative?
    dist_l = @pos.x - player_x
    dist_l += stage_width if dist_l.negative?
    @dir = if panic?
             dist_l <= dist_r ? Game::DIR_R : Game::DIR_L
           else
             dist_l <= dist_r ? Game::DIR_L : Game::DIR_R
           end
  end

  def update(dt)
    case @state
    when :Alive
      @pos.x += @dir * speed() * dt
    when :Knockedout
      @pos.x += @dir * speed() * dt
      @anim_knockedout_timer -= dt
      if @anim_knockedout_timer < 0.0
        @anim_knockedout_timer = 0.0
        set_state(:Alive)
      end
    end

    if @panic_timer > 0.0
      @panic_timer -= dt
      @panic_timer = 0.0 if @panic_timer < 0.0
    end

    @anim_leg_timer += dt
  end

  def render
    body_radius = 50.0
    leg_radius = body_radius / 3.0
    leg_amp = 2.0
    leg_cycle = 660 * Math::PI / 180.0

    leg_yofs = leg_amp * Math.cos(leg_cycle * @anim_leg_timer)

    eye_center_ofs = @dir == Game::DIR_L ? -10.0 : 10.0
    eye_center_x = @pos.x + eye_center_ofs
    eye_center_y = @pos.y - 10.0
    eye_dist = 35
    eye_l_x = eye_center_x - eye_dist * 0.5
    eye_l_y = eye_center_y
    eye_r_x = eye_center_x + eye_dist * 0.5
    eye_r_y = eye_center_y
    eye_radius_h = 12.0
    eye_radius_v = 16.0

    pupil_center_ofs = @dir == Game::DIR_L ? -15.0 : 15.0
    pupil_center_x = @pos.x + pupil_center_ofs
    pupil_center_y = @pos.y - 10.0
    pupil_dist = 35
    pupil_l_x = pupil_center_x - pupil_dist * 0.5
    pupil_l_y = pupil_center_y
    pupil_r_x = pupil_center_x + pupil_dist * 0.5
    pupil_r_y = pupil_center_y
    pupil_radius_h = 8.0
    pupil_radius_v = 10.0

    unless knockedout?
      body_color = panic? ? BLUE : RED
      # Body
      DrawCircleSector(@pos, body_radius, 45, 315, 32, body_color)
      DrawRectangle(@pos.x - body_radius, @pos.y, body_radius * 2.0, leg_radius * 2, body_color)
      # Legs
      DrawCircle(@pos.x - body_radius + leg_radius, @pos.y + body_radius - leg_radius + leg_yofs, leg_radius, body_color)
      DrawCircle(@pos.x - body_radius + leg_radius + leg_radius * 1.2, @pos.y + body_radius - leg_radius + leg_yofs, leg_radius, body_color)
      DrawCircle(@pos.x + body_radius - leg_radius - leg_radius * 1.2, @pos.y + body_radius - leg_radius + leg_yofs, leg_radius, body_color)
      DrawCircle(@pos.x + body_radius - leg_radius, @pos.y + body_radius - leg_radius + leg_yofs, leg_radius, body_color)
    end
    # Eyes
    DrawEllipse(eye_l_x, eye_l_y, eye_radius_h, eye_radius_v, WHITE)
    DrawEllipse(eye_r_x, eye_r_y, eye_radius_h, eye_radius_v, WHITE)
    DrawEllipse(pupil_l_x, pupil_l_y, pupil_radius_h, pupil_radius_v, BLUE)
    DrawEllipse(pupil_r_x, pupil_r_y, pupil_radius_h, pupil_radius_v, BLUE)
  end
end

####################################################################################################

class Player
  attr_accessor :pos

  STATES = [:Alive, :Failed]

  SPEED_NORMAL = 360.0
  SPEED_POWERUP = SPEED_NORMAL * 1.05
  POWERUP_DURATION = 3.0

  DRAW_RADIUS = 50.0
  HIT_RADIUS = 40.0
  POWERUP_RADIUS_SCALE = 2.5

  def initialize
    @pos = Vector2.create
    reset
  end

  def reset
    @pos.set(0.0, 0.0)
    @dir = Game::DIR_R
    @draw_radius = DRAW_RADIUS
    @hit_radius = HIT_RADIUS
    @powerup_timer = 0.0
    @anim_mouse_timer = 0.0
    @anim_mouse_open = true
    @anim_failed_timer = 0.0
    @anim_failed_scale = 1.0
    @state = :Alive
  end

  def set_state(new_state)
    raise ArgumentError unless STATES.include? new_state
    @state = new_state
  end
  private :set_state

  def finish = set_state(:Failed)

  def failed? = @state == :Failed

  def start_powerup = @powerup_timer = POWERUP_DURATION

  def powerup? = @powerup_timer > 0.0

  def speed = powerup? ? SPEED_POWERUP : SPEED_NORMAL

  def hit_radius = powerup? ? @hit_radius * POWERUP_RADIUS_SCALE : @hit_radius

  def update(dt)
    if IsKeyPressed(KEY_RIGHT)
      @dir = Game::DIR_R
    elsif IsKeyPressed(KEY_LEFT)
      @dir = Game::DIR_L
    end

    case @state
    when :Alive
      @pos.x += @dir * speed() * dt
      if @powerup_timer > 0.0
        @powerup_timer -= dt
        @powerup_timer = 0.0 if @powerup_timer < 0.0
      end
      @anim_mouse_open = @anim_mouse_timer <= ((1.0 / 60.0) * 4)
      @anim_mouse_timer += dt
      @anim_mouse_timer = 0.0 if @anim_mouse_timer >= ((1.0 / 60.0) * 8)
    when :Failed
      @anim_failed_scale = 1.0 - @anim_failed_timer
      @anim_failed_scale = 0.0 if @anim_failed_scale < 0.0
      @anim_failed_timer += dt
    end
  end

  def render
    radius = powerup? ? @draw_radius * POWERUP_RADIUS_SCALE : @draw_radius
    radius *= @anim_failed_scale if failed?
    body_color = if failed?
                   Fade(YELLOW, @anim_failed_scale)
                 elsif powerup?
                   if @powerup_timer <= 1.0
                     q = @powerup_timer.divmod(0.05)[0]
                     q % 2 == 0 ? ORANGE : YELLOW
                   else
                     ORANGE
                   end
                 else
                   YELLOW
                 end
    if @anim_mouse_open
      if @dir == Game::DIR_L
        DrawCircleSector(@pos, radius, -60, 240, 36, body_color)
      else
        DrawCircleSector(@pos, radius, 120, 420, 36, body_color)
      end
    else
      DrawCircle(@pos.x, @pos.y, radius, body_color)
    end
  end
end

####################################################################################################

if __FILE__ == $PROGRAM_NAME
  # Load raylib
  shared_lib_path = Gem::Specification.find_by_name('raylib-bindings').full_gem_path + '/lib/'
  case RUBY_PLATFORM
  when /mswin|msys|mingw/ # Windows
    Raylib.load_lib(shared_lib_path + 'libraylib.dll')
  when /darwin/ # macOS
    Raylib.load_lib(shared_lib_path + 'libraylib.dylib')
  when /linux/ # Ubuntu Linux (x86_64 or aarch64)
    arch = RUBY_PLATFORM.split('-')[0]
    Raylib.load_lib(shared_lib_path + "libraylib.#{arch}.so")
  else
    raise RuntimeError, "Unknown system: #{RUBY_PLATFORM}"
  end

  game = Game.new
  config = game.configs[:stage_normal]
  screen_width, screen_height = config.screen_width, config.screen_height

  # Start raylib
  SetTraceLogLevel(LOG_ERROR)
  InitWindow(screen_width, screen_height, 'Yet Another Ruby-raylib bindings : 1D dot eater')
  SetTargetFPS(60)

  # Initialize objects
  stage_height = screen_height / 4
  stage = Stage.new(screen_width, stage_height)
  stage.offset.y = screen_height * 0.5

  player = Player.new
  enemy = Enemy.new

  dot_start_offset_x = 20.0
  dot_interval = stage.width / config.dot_count.to_f
  dots = Array.new(config.dot_count) { Dot.new }
  dots.each_with_index do |dot, i|
    dot.pos.y = stage.offset.y
    dot.pos.x = dot_start_offset_x + i * dot_interval
  end

  # Prepare reset functions as lambda for later use
  reset_dots = lambda {
    begin
      success = true
      power_dot_index = rand(dots.length)
      dots.each_with_index do |dot, i|
        dot.reset(powerup_on: i == power_dot_index)
      end
      dots.each do |dot|
        success = false if dot.powerup and CheckCollisionCircles(player.pos, 2 * player.hit_radius, dot.pos, dot.radius)
      end
    end until success
  }

  reset_game = lambda {
    game.reset(keep_high_score: true)

    player.reset
    player.pos.set(stage.center.x - stage.width * 0.333, stage.offset.y)

    enemy.reset
    enemy.pos.set(stage.center.x + stage.width * 0.333, stage.offset.y)

    reset_dots.call
  }
  reset_game.call

  until WindowShouldClose()
    # Press R to restart
    reset_game.call if IsKeyPressed(KEY_R)

    dt = GetFrameTime()

    # Update objects
    game.update(dt)

    unless game.ready?
      # Update characters and wrap position
      enemy.run_ai(player_x: player.pos.x, stage_width: stage.width)
      [player, enemy].each do |character|
        character.update(dt)
        if character.pos.x > stage.width
          character.pos.x = 0
        elsif character.pos.x < 0
          character.pos.x = stage.width
        end
      end

      # Check collision
      # player vs dots
      dots.each do |dot|
        unless dot.eaten?
          if CheckCollisionCircles(player.pos, player.hit_radius, dot.pos, dot.radius)
            game.current_score += dot.score
            if dot.powerup
              player.start_powerup
              enemy.start_panic
            end
            dot.hide
          end
        end
      end
      # player vs enemy
      unless enemy.knockedout?
        if CheckCollisionCircles(player.pos, player.hit_radius, enemy.pos, enemy.hit_radius)
          if player.powerup? # Allow player to eat enemy and get bonus
            enemy.knockout
            game.current_score += enemy.score
          else # player is caught by enemy -> game over
            game.finish
            enemy.finish
            player.finish
          end
        end
      end

      # Reactivate dots
      reset_dots.call if dots.all? {|dot| dot.eaten?}
    end

    # Render scene
    BeginDrawing()
      ClearBackground(BLACK)

      # Render objects
      stage.render
      dots.each(&:render)
      player.render
      enemy.render

      # Render UI
      # Event message
      msg_font_size = 35
      if game.ready?
        text_width = MeasureText('READY?', msg_font_size)
        q = game.state_timer.divmod(0.1)[0]
        DrawText('READY?', 0.5 * screen_width - text_width * 0.5, 70, msg_font_size, RED) if q % 2 == 0
      elsif game.game_over?
        text_widths = [
          MeasureText('GAME OVER', msg_font_size),
          MeasureText('Press R to restart', msg_font_size)
        ]
        DrawText('GAME OVER', 0.5 * screen_width - text_widths[0] * 0.5, 70, msg_font_size, RED)
        DrawText('Press R to restart', 0.5 * screen_width - text_widths[1] * 0.5, 100, msg_font_size, RED)
      end

      # Scores
      DrawText('1UP', 20, 10, 25, RED)
      DrawText("#{game.current_score}", 20, 35, 25, WHITE)

      score_font_size = 25
      hiscore_header = 'HIGH SCORE'
      hiscore_header_width = MeasureText(hiscore_header, score_font_size)
      hiscore_value = "%10d" % game.high_score
      hiscore_value_width = MeasureText(hiscore_value, score_font_size)
      hiscore_value_offset = (hiscore_header_width - hiscore_value_width).abs

      hiscore_header_x = 0.5 * screen_width - hiscore_header_width * 0.5
      hiscore_value_x = hiscore_header_x + hiscore_value_offset
      DrawText(hiscore_header, hiscore_header_x, 10, score_font_size, RED)
      DrawText(hiscore_value,  hiscore_value_x,  35, score_font_size, WHITE)

      # Help message
      help_base_x = screen_width - 300
      help_base_y = screen_height - 100
      help_msg_x = help_base_x + 10
      help_msg_base_y = help_base_y + 10
      DrawRectangle(help_base_x, help_base_y, 280, 80, Fade(MAROON, 0.25))
      DrawRectangleLines(help_base_x, help_base_y, 280, 80, GRAY)
      DrawText('Left/Right : move player', help_msg_x, help_msg_base_y + 0, 20, WHITE)
      DrawText('R : restart game', help_msg_x, help_msg_base_y + 20, 20, WHITE)
      DrawText('ESC : exit', help_msg_x, help_msg_base_y + 40, 20, WHITE)
      # FPS
      # DrawFPS(screen_width - 100, 16)
    EndDrawing()
  end

  CloseWindow()
end
