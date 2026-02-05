extends Node

signal beat_hit()
signal half_beat_hit()

const SCROLL_DISTANCE = 1.6 # units
const SCROLL_TIME = 5.50 # sec

# NOTE: changed from preload(...) to lazy-loaded resource cache to avoid parse-time preloads
var COUNTDOWN_PATHS = [
	"res://Assets/Stages/RhythmSystem/countdown/intro3.ogg",
	"res://Assets/Stages/RhythmSystem/countdown/intro2.ogg",
	"res://Assets/Stages/RhythmSystem/countdown/intro1.ogg",
	"res://Assets/Stages/RhythmSystem/countdown/introGo.ogg"
]

const PLAY_STATE = preload("res://Scenes/States/PlayState.tscn")

# ---------------------
# runtime / GC-friendly state
# ---------------------
var _res_cache := {}               # path -> Resource (caches loads)
var _temp_array := []              # reused temporary arrays to avoid many allocations
var _section_array := []
var _strum_times := []
var _notes_buffer := []

# ---------------------
# song state
# ---------------------
var songData
var songName
var songDifficulty

var bpm = 100.0
var scroll_speed = 1
var song_speed = 1
var h = false # needed so we dont die lmao
var MusicStream
var VocalStream

var countingDown = false
var countdown = 0
var countdownState = 0

var useCountdown = false

var beatCounter = 1
var halfBeatCounter = 0

var loaded = false
var muteVocals = false

var songPositionMulti = 0

var noteThread
var notesFinished = false

var menuSong = false

# ---------------------
# Resource helper
# ---------------------
func _safe_load(path: String):
	if path == null or path == "":
		return null
	if _res_cache.has(path):
		return _res_cache[path]
	var res = null
	# Use ResourceLoader to be explicit - returns null if missing
	if ResourceLoader.exists(path):
		res = ResourceLoader.load(path)
	_res_cache[path] = res
	return res

func _get_countdown_sound(i: int):
	if i < 0 or i >= COUNTDOWN_PATHS.size():
		return null
	return _safe_load(COUNTDOWN_PATHS[i])

# ---------------------
func _ready():
	MusicStream = self
	VocalStream = $Vocals

	# do not start creating notes in a thread that touches the scene tree;
	# create_notes touches get_tree().current_scene — run it on main thread
	# If you want threaded loading, move heavy parsing code there, but don't access tree.
	# Start create_notes only when play_chart is called (we call create_notes there).
	# Keep noteThread available if you want to use it for non-tree work later.
	noteThread = Thread.new()

func _scene_loaded():
	loaded = true
	print("loaded")

func _process(delta):
	if !(loaded):
		return

	# fast volume toggle (no allocations)
	if muteVocals:
		VocalStream.volume_db = -80
	else:
		VocalStream.volume_db = 0

	if (notesFinished):
		beat_process(delta)
		if (useCountdown):
			countdown_process(delta)
		song_finished_check()

	var countdownMulti = ((countdown / (bpm / 60)) * 2)
	songPositionMulti = MusicStream.get_playback_position() - countdownMulti
	if (menuSong and MusicController.playing):
		beat_process(delta)
		song_finished_check()

func _exit_tree():
	# use wait_to_finish only if thread started
	if noteThread.is_active():
		noteThread.wait_to_finish()

# ---------------------
# Playback API
# ---------------------
func play_song(song, newerBpm, speed = 1, _menuSong = true):
	song_speed = speed
	menuSong = _menuSong
	notesFinished = false
	change_bpm(newerBpm)

	if (typeof(song) == TYPE_OBJECT):
		MusicStream.stream = song
	else:
		MusicStream.stream = _safe_load(song)
	MusicStream.pitch_scale = song_speed
	MusicStream.play()

	# stop vocals and clear stream reference if none
	VocalStream.stop()

	useCountdown = false

func play_chart(song, difficulty, speed = 1):
	songName = song
	menuSong = false
	var difExt = "-" + difficulty

	match difficulty:
		"easy":
			songDifficulty = 0
		"normal":
			songDifficulty = 0
			difExt = ""
		"hard":
			songDifficulty = 0

	var songPath = "res://Assets/Songs/" + songName  + "/"
	print(difExt)
	songData = load_song_json(songName, difExt, songPath)

	song_speed = speed
	change_bpm(songData.get("bpm", bpm))

	scroll_speed = songData.get("speed", 1)

	# create notes on main thread (create_notes uses current_scene)
	create_notes()

	# Use cached loads to reduce allocations
	MusicStream.stream = _safe_load(songPath + "Inst.ogg")
	MusicStream.pitch_scale = song_speed

	if songData.has("needsVoices") and songData["needsVoices"]:
		VocalStream.stream = _safe_load(songPath + "Voices.ogg")
		VocalStream.pitch_scale = song_speed
	else:
		VocalStream.stream = null

	countdown = 2.8
	useCountdown = true

	var countDownOffset = 0.0
	if get_tree().current_scene.notes.size() > 0:
		countDownOffset = get_tree().current_scene.notes[0][0] - ((countdown / (bpm / 60)) * 2)
		if (countDownOffset < 0):
			countdown -= countDownOffset

func change_bpm(newBpm, newScrollSpeed = null):
	bpm = float(newBpm)
	beatCounter = 1
	if (newScrollSpeed != null):
		scroll_speed = newScrollSpeed

# ---------------------
# Note creation (GC-reduced)
# ---------------------
func create_notes():
	# reuse buffers instead of allocating new arrays each time
	_temp_array.clear()
	_section_array.clear()
	_strum_times.clear()
	_notes_buffer.clear()

	notesFinished = false

	# local alias to avoid repeated dictionary lookups
	var song_notes = songData.get("notes", [])
	var sections_local := []
	var last_note = null

	for section in song_notes:
		var section_time = (((60 / bpm) / 4) * 16) * sections_local.size()
		var sectionData = [section_time, section.get("mustHitSection", false)]
		sections_local.append(sectionData)

		for note in section.get("sectionNotes", []):
			var strum_time = (note[0] + Settings.offset) / 1000.0
			var sustain_length = int(note[2]) / 1000.0
			var direction = int(note[1])

			if (!section.get("mustHitSection", false)):
				if (direction <= 3):
					direction += 4
				else:
					direction -= 4

			var noteData = [strum_time, direction, sustain_length]

			if (last_note != null):
				_temp_array.append(last_note)
				if (!_section_array.empty()):
					_temp_array.append_array(_section_array)
					_section_array.clear()
				last_note = noteData
			else:
				last_note = noteData

	# finish up
	if last_note != null:
		_temp_array.append(last_note)

	# build sorted order using preallocated buffers
	for tmp_note in _temp_array:
		_strum_times.append(tmp_note[0])

	_strum_times.sort()

	# create final notes list
	while !_temp_array.empty():
		var index := 0
		while _strum_times[0] != _temp_array[index][0]:
			index += 1
		_notes_buffer.append(_temp_array[index])
		_strum_times.remove(0)
		_temp_array.remove(index)

	# assign to playstate
	var playState = get_tree().current_scene
	playState.notes = _notes_buffer.duplicate() # duplicate to avoid accidental shared mutation
	playState.sections = sections_local

	notesFinished = true

# ---------------------
func countdown_process(delta):
	var playState = get_tree().current_scene
	var countdownSprite = playState.get_node("HUD/Countdown")
	var stream = playState.get_node("Audio/CountdownStream")

	if (countdown > 0):
		countingDown = true
		countdown -= ((bpm / 60) / 2) * song_speed * delta

	if (countingDown):
		# compute countdown state safely (avoid allocations)
		countdownState = int(ceil((fmod(countdown / 5, countdown) * 10)))

		match countdownState:
			4:
				play_countdown_sound(stream, _get_countdown_sound(0))
			3:
				play_countdown_sound(stream, _get_countdown_sound(1))
				countdownSprite.visible = true
				countdownSprite.frame = 0
			2:
				play_countdown_sound(stream, _get_countdown_sound(2))
				countdownSprite.visible = true
				countdownSprite.frame = 1
			1:
				play_countdown_sound(stream, _get_countdown_sound(3))
				countdownSprite.visible = true
				countdownSprite.frame = 2

		if (countdown <= 0):
			start_song()
			countdownSprite.visible = false
			countingDown = false
			countdown = 0

func start_song():
	MusicStream.play()
	VocalStream.play()
	change_bpm(bpm)

func play_countdown_sound(stream, snd):
	if (stream != null and snd != null):
		if (stream.stream != snd):
			stream.stream = snd
			stream.play()

func beat_process(delta):
	beatCounter -= ((bpm / 60) * song_speed) * delta
	if (beatCounter <= 0):
		beatCounter = beatCounter + 1
		halfBeatCounter += 1
		emit_signal("beat_hit")
		if (halfBeatCounter >= 2):
			emit_signal("half_beat_hit")
			halfBeatCounter = 0

func song_finished_check():
	if (MusicStream.get_playback_position() >= (MusicStream.stream != null ? MusicStream.stream.get_length() : 0)):
		if Resources.StoryMode:
			if get_tree().current_scene.name == "PlayState" and countingDown == false and h == false and menuSong == false:
				h = true
				MusicController.stop_song()
				print("h")
				SceneLoader.Load("res://Scenes/Menus/StoryModeMenu.tscn")
				yield(SceneLoader, "done")
				h = false
		else:
			if get_tree().current_scene.name == "PlayState" and countingDown == false and h == false and menuSong == false:
				h = true
				MusicController.stop_song()
				print("going to freeplay")
				SceneLoader.Load("res://Scenes/Menus/Freeplay.tscn")
				yield(SceneLoader, "done")
				h = false

func stop_song():
	if (MusicStream.playing):
		MusicStream.stop()
		VocalStream.stop()
		VocalStream.stream = null
		menuSong = false
		useCountdown = false
		beat_process(0)

func load_song_json(song, difExt="", songPath = null):
	if (songPath == null):
		songPath = "res://Assets/Songs/" + song  + "/"

	var file = File.new()
	if file.file_exists(songPath + song + difExt + ".json"):
		file.open(songPath + song + difExt + ".json", File.READ)
		var parsed = JSON.parse(file.get_as_text())
		if parsed.error == OK:
			return parsed.result.get("song", {})
	return {}

