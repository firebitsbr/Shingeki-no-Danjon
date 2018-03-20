extends "res://Scripts/BaseEnemy.gd"

const BASIC_DAMAGE         = 10
const SPECIAL_DAMAGE       = 20

const SPECIAL_PROBABILITY  = 200
const ATACK_SPEED          = 125

const SPEED                = 100

const KNOCKBACK_ATACK      = 10 

const FOLLOW_RANGE         = 400
const PERSONAL_SPACE       = 30
const TIME_OF_LIYUGN_CORPS = 3

var player
var direction       = "Down"
var dead_time       = 0

var can_use_special = true
var dead            = false

var follow_player   = false
var in_action       = false
var special_ready   = false
var atack_ready     = true

onready var sprites = $Sprites.get_children()

func _ready():
	._ready()

func _physics_process(delta):
	._physics_process(delta)
	
	if dead :
		dead_time += delta
		if dead_time > TIME_OF_LIYUGN_CORPS: queue_free()
		return
	
	if follow_player and !in_action :
		
		if( !special_ready ) : special_ready = (randi()%SPECIAL_PROBABILITY == 0)
		if( !  atack_ready ) : atack_ready   = (randi()%ATACK_SPEED         == 0)
		
		var move = Vector2(sign(player.position.x - position.x), sign(player.position.y - position.y)).normalized() * SPEED * delta

		
		var axix_X = abs(position.x - player.position.x) >= PERSONAL_SPACE
		var axix_Y = abs(position.y - player.position.y) >= PERSONAL_SPACE
		

		#if( axix_X and axix_Y):
		move_and_slide(move * SPEED)
		
		if axix_X:

			sprites[0].flip_h = move.x > 0
			if abs(move.x) > 1: 
				play_animation_if_not_playing("Left")
				direction = "Right" if move.x > 0 else "Left"
#				elif move.x > 0: play_animation_if_not_playing("Right") na później
		elif axix_Y:

			if move.y < 0: 
				play_animation_if_not_playing("Down")
				direction = "Up"
			elif move.y > 0: 
				play_animation_if_not_playing("Up")
				direction = "Down"
		else:
			play_animation_if_not_playing("Down")
			direction = "Down"
	
		var player_monster_distance_x = abs(position.x - player.position.x) 
		var player_monster_distance_y = abs(position.y - player.position.y) 

		if player_monster_distance_x > FOLLOW_RANGE and player_monster_distance_y > FOLLOW_RANGE:
			follow_player = false
		
		if player_monster_distance_x < 79 and player_monster_distance_y < 79:
			if special_ready and can_use_special:
				in_action = true
				play_animation_if_not_playing("Special")
				damage = SPECIAL_DAMAGE
				knockback = KNOCKBACK_ATACK
			elif atack_ready:
				in_action = true
				atack_ready = false
				
				punch_in_direction()
				damage = BASIC_DAMAGE
				knockback = 0


func punch_in_direction():
	print(direction)
	if direction == "Right" : 
		sprites[1].flip_h = true
		play_animation_if_not_playing("PunchLeft")
	else:
		sprites[1].flip_h = false
		play_animation_if_not_playing("Punch" + direction)


func play_animation_if_not_playing(anim):
	if $AnimationPlayer.current_animation != anim:
		$"AnimationPlayer".play(anim)

func _on_Area2D_body_entered(body):
	if body.name == "Player":
		follow_player = true;
		player = body

func _on_animation_started(anim_name):
	var anim = $AnimationPlayer.get_animation(anim_name)
	
	if anim and sprites:
		var main_sprite = int(anim.track_get_path(0).get_name(1))
	
		for i in range(sprites.size()):
			sprites[i].visible = (i+1 == main_sprite)

func _on_dead():
	dead = true
	$"AnimationPlayer".play("Dead")
	$"Shape".disabled = true

func _on_damage():
	print("oof")

func _on_animation_finished(anim_name):
	if anim_name == "Special":
		special_ready = false
		in_action     = false
	elif anim_name == "PunchDown":
		in_action     = false
	elif anim_name == "PunchLeft":
		in_action     = false
	elif anim_name == "PunchUp":
		in_action     = false
