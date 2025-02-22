class_name BombItem
extends ConsumableItem


export var radius = 5 # meters
#export var fragments = 200 # number of raycasts and/or particles
export var bomb_damage : float #amount of damage to be registered
export(AttackTypes.Types) var damage_type : int = 0

var countdown_started = false

onready var countdown_timer = $Countdown
onready var flash = $Flash
var fuse_sound

var throwing = false


func _ready():
	print($Explosion.lifetime)


func _process(delta):
	if countdown_started == true:
		$Explosion.lifetime -= delta
	if $Explosion.lifetime < 1.2:
		queue_free()
		
	if throwing == true:
		owner_character.player_controller.throw_state = owner_character.player_controller.ThrowState.SHOULD_THROW
		print("Throw state set to 3, so this should say 3: ", owner_character.player_controller.throw_state)
		owner_character.player_controller.update_throw_state(self, delta)
		throwing = false


func _use_primary():
	if countdown_timer.is_stopped():
		countdown_timer.start()
		$Fuse.emitting = true
		if fuse_sound:
			fuse_sound.play()
	else:
		print("Trying to throw bomb")
#		owner_character.drop_consumable(self)   # TODO: just replace this with standard throw logic for simplificy? Any reason to have this?
		if owner_character is Player:
			throwing = true
			print("Player is the one trying to throw")


func _on_Countdown_timeout():
	item_max_noise_level = 80
	noise_level = 80   # Noise detectable by characters
	flash.get_node("FlashTimer").start()
	flash.visible = true
	$Effect.handle_sound()
	$Explosion.emitting = true
	$Shrapnel.emitting = true
	$Fuse.emitting = false
	$MeshInstance.visible = false
	$Explosion._on_Bomb_explosion()
	countdown_started = true
	# If it blows up in hand
	if owner_character.is_in_group("CHARACTER") and !item_state == GlobalConsts.ItemState.DROPPED:
#		print("Bomb blew up in ", owner_character, "'s hand for ", fragments / 4 * bomb_damage, " damage.")
		owner_character.damage(bomb_damage, damage_type, owner_character)
		throwing = true
	
	# Camera shake, untested
	if owner_character.is_in_group("PLAYER") and $Explosion/BlastRadius.get_overlapping_bodies(owner_character):
		owner_character.fps_camera.add_stress(0.5)   # Eventually maybe based on distance from explosion


func _on_FlashTimer_timeout():
	flash.visible = false
