class_name StoryAudio
extends StoryCrew
## Crew member for music, sound effects, ambience, and voice lines.
##
## Files are found by name in subfolders of [member StoryConfig.audio_folder]:
## [code]music/[/code], [code]sounds/[/code], [code]ambience/[/code], and
## [code]voice/[/code] (ogg, mp3, or wav). Each kind plays on its own audio
## bus when the project defines it ("Music", "Sounds", "Ambience", "Voice"),
## otherwise on "Master".
##
## Lines marked [code]@voice("clip")[/code] play their clip automatically.

const KINDS := ["music", "sounds", "ambience", "voice"]
const BUS_NAMES := {"music": "Music", "sounds": "Sounds", "ambience": "Ambience", "voice": "Voice"}

var audio_folder := "res://story/audio"
## Player-controlled volume per kind, from 0 to 1.
var volumes := {"music": 1.0, "sounds": 1.0, "ambience": 1.0, "voice": 1.0}

var _music: Array[AudioStreamPlayer] = []
var _music_index := 0
var _music_state := {"track": "", "volume": 1.0, "loop": true}
var _ambience: AudioStreamPlayer
var _ambience_state := {"track": "", "volume": 1.0}
var _voice: AudioStreamPlayer
var _voice_clip := ""
var _sounds: Array[AudioStreamPlayer] = []
## Linear volume of each player before the per-kind volume is applied.
var _levels: Dictionary = {}
var _tweens: Dictionary = {}


func get_crew_name() -> StringName:
	return &"Audio"


func setup(config: StoryConfig) -> void:
	audio_folder = config.audio_folder
	for i in 2:
		var player := _make_player("Music%d" % (i + 1), "music")
		player.finished.connect(_on_music_finished.bind(player))
		_music.append(player)
	_ambience = _make_player("Ambience", "ambience")
	_ambience.finished.connect(func() -> void:
		if not _ambience_state["track"].is_empty():
			_ambience.play())
	_voice = _make_player("Voice", "voice")
	_connect_director.call_deferred()


func clear() -> void:
	stop_all(0.0)


## Plays a music track, crossfading from the current one over [param fade]
## seconds. Playing the track that is already on only changes its volume.
## Returns an error message or "".
func play_music(track: String, volume := 1.0, fade := 1.0, loop := true) -> String:
	var current := _music[_music_index]
	if _music_state["track"] == track and current.playing:
		_music_state["volume"] = volume
		_music_state["loop"] = loop
		_fade_to(current, volume, fade)
		return ""
	var stream := find_stream("music", track)
	if stream == null:
		return "Music '%s' was not found in %s." % [track, audio_folder.path_join("music")]
	_fade_to(current, 0.0, fade, true)
	_music_index = 1 - _music_index
	var next := _music[_music_index]
	next.stream = stream
	_set_level(next, 0.0 if fade > 0.0 and not _is_skipping() else volume)
	next.play()
	_fade_to(next, volume, fade)
	_music_state = {"track": track, "volume": volume, "loop": loop}
	return ""


func stop_music(fade := 1.0) -> void:
	_music_state["track"] = ""
	for player in _music:
		_fade_to(player, 0.0, fade, true)


## Plays a sound effect. Awaitable: returns when the sound ends.
## Returns an error message or "".
func play_sound(sound_name: String, volume := 1.0) -> String:
	var stream := find_stream("sounds", sound_name)
	if stream == null:
		return "Sound '%s' was not found in %s." % [sound_name, audio_folder.path_join("sounds")]
	if _is_skipping():
		return ""
	var player := _free_sound_player()
	player.stream = stream
	_set_level(player, volume)
	player.play()
	await _wait_until_done(player)
	return ""


## Plays a looping background sound, fading from the current one.
func play_ambience(track: String, volume := 1.0, fade := 1.0) -> String:
	if _ambience_state["track"] == track and _ambience.playing:
		_ambience_state["volume"] = volume
		_fade_to(_ambience, volume, fade)
		return ""
	var stream := find_stream("ambience", track)
	if stream == null:
		return "Ambience '%s' was not found in %s." % [track, audio_folder.path_join("ambience")]
	_ambience_state = {"track": track, "volume": volume}
	_ambience.stream = stream
	_set_level(_ambience, 0.0 if fade > 0.0 and not _is_skipping() else volume)
	_ambience.play()
	_fade_to(_ambience, volume, fade)
	return ""


func stop_ambience(fade := 1.0) -> void:
	_ambience_state["track"] = ""
	_fade_to(_ambience, 0.0, fade, true)


## Plays a voice clip, stopping the previous one. Awaitable: returns when the
## clip ends. Returns an error message or "".
func play_voice(clip: String) -> String:
	var stream := find_stream("voice", clip)
	if stream == null:
		return "Voice clip '%s' was not found in %s." % [clip, audio_folder.path_join("voice")]
	stop_voice()
	if _is_skipping():
		return ""
	_voice.stream = stream
	_set_level(_voice, 1.0)
	_voice.play()
	_voice_clip = clip
	await _wait_until_done(_voice)
	if _voice_clip == clip and _voice.stream == stream:
		_voice_clip = ""
	return ""


func stop_voice() -> void:
	_voice.stop()
	_voice_clip = ""


## Name of the voice clip playing now, or "".
func get_voice_clip() -> String:
	return _voice_clip


## Stops music, ambience, sounds, and voice.
func stop_all(fade := 0.5) -> void:
	stop_music(fade)
	stop_ambience(fade)
	stop_voice()
	for player in _sounds:
		player.stop()


func get_music_track() -> String:
	return _music_state["track"]


func get_ambience_track() -> String:
	return _ambience_state["track"]


## Sets the player volume (0 to 1) for "music", "sounds", "ambience", or "voice".
func set_kind_volume(kind: String, volume: float) -> void:
	volumes[kind] = clampf(volume, 0.0, 1.0)
	for player in _all_players():
		_apply_volume(player)


## Starts loading an audio file in the background.
func preload_asset(kind: String, asset_name: String) -> void:
	var folder := {"music": "music", "sound": "sounds", "ambience": "ambience", "voice": "voice"}.get(kind, "")
	if not folder.is_empty():
		StoryAssets.preload_path(StoryAssets.find(audio_folder.path_join(folder), asset_name, StoryAssets.AUDIO_EXTENSIONS))


## Finds "<name>.<ogg|mp3|wav>" in the folder for [param kind], or null.
func find_stream(kind: String, stream_name: String) -> AudioStream:
	return StoryAssets.load_asset(audio_folder.path_join(kind), stream_name, StoryAssets.AUDIO_EXTENSIONS) as AudioStream


func capture() -> Dictionary:
	return {"music": _music_state.duplicate(), "ambience": _ambience_state.duplicate()}


func restore(data: Dictionary) -> void:
	stop_all(0.0)
	var music: Dictionary = data.get("music", {})
	if not music.get("track", "").is_empty():
		play_music(music["track"], music.get("volume", 1.0), 0.0, music.get("loop", true))
	var ambience: Dictionary = data.get("ambience", {})
	if not ambience.get("track", "").is_empty():
		play_ambience(ambience["track"], ambience.get("volume", 1.0), 0.0)


func _make_player(player_name: String, kind: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.set_meta("kind", kind)
	var bus: String = BUS_NAMES[kind]
	player.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
	add_child(player)
	_set_level(player, 1.0)
	return player


func _free_sound_player() -> AudioStreamPlayer:
	for player in _sounds:
		if not player.playing:
			return player
	var player := _make_player("Sound%d" % (_sounds.size() + 1), "sounds")
	_sounds.append(player)
	return player


func _set_level(player: AudioStreamPlayer, level: float) -> void:
	_levels[player] = level
	_apply_volume(player)


func _apply_volume(player: AudioStreamPlayer) -> void:
	var kind: String = player.get_meta("kind")
	var linear: float = _levels.get(player, 1.0) * volumes.get(kind, 1.0)
	player.volume_db = linear_to_db(maxf(linear, 0.0001))


func _fade_to(player: AudioStreamPlayer, level: float, time: float, stop_after := false) -> void:
	if _tweens.has(player) and _tweens[player].is_valid():
		_tweens[player].kill()
	if time <= 0.0 or _is_skipping() or not is_inside_tree() or not player.playing:
		_set_level(player, level)
		if stop_after:
			player.stop()
		return
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: _set_level(player, value), _levels.get(player, 1.0), level, time)
	if stop_after:
		tween.tween_callback(player.stop)
	_tweens[player] = tween


## Waits for a non-looping player to finish. Uses the stream length so it
## also works without an audio device.
func _wait_until_done(player: AudioStreamPlayer) -> void:
	var length := player.stream.get_length() / maxf(player.pitch_scale, 0.01)
	if length <= 0.0 or not is_inside_tree():
		return
	await get_tree().create_timer(length).timeout


func _on_music_finished(player: AudioStreamPlayer) -> void:
	if player == _music[_music_index] and _music_state["loop"] and not _music_state["track"].is_empty():
		player.play()


func _all_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	players.append_array(_music)
	players.append_array(_sounds)
	players.append(_ambience)
	players.append(_voice)
	return players


func _connect_director() -> void:
	var director := _director()
	if director != null and not director.line_started.is_connected(_on_line_started):
		director.line_started.connect(_on_line_started)


func _on_line_started(line: Dictionary) -> void:
	stop_voice()
	var clip: String = line.get("voice", "")
	if not clip.is_empty():
		var problem: String = await play_voice(clip)
		if not problem.is_empty():
			_director().report_error(problem)


func _is_skipping() -> bool:
	var director := _director()
	return director != null and director.skipping


func _director() -> TaleDirector:
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(&"TaleDirector") as TaleDirector
	return null
