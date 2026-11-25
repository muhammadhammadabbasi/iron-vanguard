extends Node
## Sound effects + voice-over playback. Autoloaded as "Sfx".

const NAMES := ["rifle_shot", "enemy_shot", "reload", "empty_click", "pin_pull", "step1", "step2", "step3",
	"hitmarker", "kill_confirm", "explosion", "radio_beep", "wind", "impact", "whiz", "hurt", "bounce",
	"heli", "ui_click", "objective", "pistol_silenced", "sniper_shot", "smg_shot", "ak_shot", "knife_swing",
	"knife_hit", "alarm", "c4_beep", "chute_open", "freefall", "plane_engine", "pickup", "medkit", "camera_alert",
	"console", "land"]

signal voice_started(speaker: String, text: String, duration: float)

var streams := {}
var subtitles := {}
var voice_player: AudioStreamPlayer
var shout_cd := 0.0
var _extra := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		streams[n] = load("res://audio/%s.wav" % n)
	_make_bus("Voice", 2.0)
	_make_bus("SFX", 0.0)
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Voice"
	add_child(voice_player)
	if FileAccess.file_exists("res://assets/voice/subtitles.json"):
		var f := FileAccess.open("res://assets/voice/subtitles.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			subtitles = d


func _process(delta: float) -> void:
	shout_cd -= delta


func _make_bus(bus_name: String, db: float) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_volume_db(i, db)
	AudioServer.set_bus_send(i, "Master")


func _stream(sound: String) -> AudioStream:
	if streams.has(sound):
		return streams[sound]
	if _extra.has(sound):
		return _extra[sound]
	var path := "res://assets/voice/%s.ogg" % sound
	if ResourceLoader.exists(path):
		_extra[sound] = load(path)
		return _extra[sound]
	return null


func play(sound: String, vol_db := 0.0, pitch_var := 0.05) -> AudioStreamPlayer:
	var s := _stream(sound)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = vol_db
	p.bus = "SFX"
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func play3d(sound: String, pos: Vector3, vol_db := 0.0, max_dist := 120.0, pitch_var := 0.06) -> AudioStreamPlayer3D:
	var root: Node = Fx.root()
	var s := _stream(sound)
	if root == null or s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = vol_db
	p.unit_size = 10.0
	p.max_distance = max_dist
	p.bus = "SFX"
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	root.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Plays a voice line (radio / player voice). Returns its duration in seconds.
func voice(id: String) -> float:
	var info: Dictionary = subtitles.get(id, {})
	var text: String = info.get("text", "")
	var speaker: String = info.get("speaker", "")
	var s := _stream(id)
	var dur := 2.5
	if s != null:
		voice_player.stop()
		voice_player.stream = s
		voice_player.play()
		dur = s.get_length() + 0.25
	elif text != "":
		dur = clampf(text.length() * 0.065, 1.8, 7.0)
	if speaker in ["malik", "raven"]:
		play("radio_beep", -14.0, 0.0)
	voice_started.emit(speaker, text, dur)
	return dur


## Enemy shout from a 3D position, rate-limited so soldiers don't talk over each other.
func shout(kind: String, pos: Vector3, voice_index := 1) -> void:
	if shout_cd > 0.0:
		return
	shout_cd = 1.6
	var p := play3d("enemy%d_%s" % [voice_index, kind], pos, 2.0, 60.0, 0.04)
	if p != null:
		p.bus = "Voice"
