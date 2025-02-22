extends Spatial
class_name BaseKinematicDoor

#
# This is a simplified door model, with toggle open/close
# Done due to limitations in Godot 3 making it difficult to implement
# a fully simulated Rigid Body door
#


enum DoorState {
	OPEN,
	CLOSED,
	STUCK,
	BROKEN
}

var broken_door_scene : PackedScene = preload("res://scenes/objects/large_objects/doors/base_broken_door.tscn")

export var health : float = 100.0

var navigation_areas : Array
var door_state : int = DoorState.CLOSED

var door_move_time = 0.5
var door_open_angle = deg2rad(100)
var door_close_threshold = deg2rad(5)
var door_speed = door_open_angle/door_move_time
var door_should_move = false

onready var door_body = $"%DoorBody"
onready var door_hinge_z_axis = $"%DoorHingeZAxis"
onready var open_block_detector = $"%OpenBlockDetector"
onready var close_block_detector = $"%CloseBlockDetector"
onready var doorway_gaps_filler = $"%DoorwayGapsFiller"
onready var npc_detector = $"%NpcDetector"
onready var broken_door_origin: Spatial = $"%BrokenDoorOrigin"

onready var door_kick_ineffective_sound: AudioStreamPlayer3D = $Sounds/DoorKickIneffectiveSound
onready var door_kick_effective_sound: AudioStreamPlayer3D = $Sounds/DoorKickEffectiveSound
onready var door_break_sound: AudioStreamPlayer3D = $Sounds/DoorBreakSound


func _physics_process(delta):
	if not door_should_move:
		return
	match door_state:
		DoorState.OPEN:
			if door_hinge_z_axis.rotation.y < door_open_angle:
				for obstacle in open_block_detector.get_overlapping_bodies():
					if not obstacle in [door_body, doorway_gaps_filler]:
						door_should_move = false
						if door_hinge_z_axis.rotation.y < door_close_threshold:
							door_state = DoorState.CLOSED
							door_should_move = true
						return
				door_hinge_z_axis.rotation.y = move_toward(door_hinge_z_axis.rotation.y, door_open_angle, door_speed*delta)
		DoorState.CLOSED:
			if door_hinge_z_axis.rotation.y > 0.0:
				for obstacle in close_block_detector.get_overlapping_bodies():
					if not obstacle in [door_body, doorway_gaps_filler]:
						door_should_move = false
						if door_hinge_z_axis.rotation.y > door_close_threshold:
								door_state = DoorState.OPEN
								if door_hinge_z_axis.rotation.y > door_open_angle - door_close_threshold:
									door_should_move = true
						return
				door_hinge_z_axis.rotation.y = move_toward(door_hinge_z_axis.rotation.y, 0.0, door_speed*delta)
		DoorState.STUCK:
			door_should_move = false
			pass


func _on_Interactable_character_interacted(character):
	match door_state:
		DoorState.CLOSED:
			door_state = DoorState.OPEN
			door_should_move = true
			$Sounds/DoorClose.stop()
			if !$Sounds/DoorOpen.playing:
				$Sounds/DoorOpen.play()
		
		DoorState.OPEN:
			door_state = DoorState.CLOSED
			door_should_move = true
			$Sounds/DoorOpen.stop()
			if !$Sounds/DoorClose.playing:
				$Sounds/DoorClose.play()
		
		DoorState.STUCK:
			$Sounds/DoorKickIneffectiveSound.play()
			pass


# TODO: Shooting doors not currently working
#func damage(damage_amount, damage_type, target):
#	if damage_amount < 10:
#		door_kick_ineffective_sound.play()
#	else:
#		door_kick_effective_sound.play()
#	health -= damage_amount
#	print("Door health : ", health)
#	if health <= 0:
#		break_door()


func break_door(position, impulse, damage):
	door_state = DoorState.BROKEN
	door_break_sound.play()
	var global_door_transform = broken_door_origin.global_transform
	door_hinge_z_axis.queue_free()
	var broken_door_instance : Spatial = broken_door_scene.instance()
	broken_door_instance.transform = global_transform.affine_inverse() * global_door_transform
	add_child(broken_door_instance)
	broken_door_instance.apply_impulse(position, impulse * (damage / 5.0), 0.0)


func _on_Interactable_kicked(position, impulse, damage) -> void:
	health -= damage
	door_kick_effective_sound.play()
	print("Door health : ", health)
	if health <= 0:
		break_door(position, impulse, damage)


func _on_NpcDetector_body_entered(body):
	door_state = DoorState.OPEN
	door_should_move = true


func _on_NpcCheckTimer_timeout():
	if npc_detector.get_overlapping_bodies().size() > 0:
		door_state = DoorState.OPEN
		door_should_move = true
