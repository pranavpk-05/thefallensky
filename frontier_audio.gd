extends Node

const SAMPLE_RATE := 22050
const BREEZE_SECONDS := 8
const SCORE := {
	&"title": "black-signal",
	&"explore": "forgotten-valley",
	&"investigate": "evidence-of-the-dead",
	&"chase": "someone-is-following",
	&"flight": "above-the-storm",
	&"reveal": "the-truth-below",
}

var _ambience: AudioStreamPlayer
var _score: AudioStreamPlayer
var _outgoing: AudioStreamPlayer
var _cue: StringName = &"title"
var _loaded_score: Dictionary[StringName, AudioStreamOggVorbis] = {}
var _blend := 0.0
var _duck := false
var _duck_gain := 1.0
var _spatial: Array[AudioStreamPlayer3D] = []
var _stride_distance := 0.0
var _storm_delay := -1.0
var _heard_flash := false
var _next_forest_call := 9.0
var _at := Vector3.ZERO
var _tones: Array[AudioStreamPlayer] = []
var _streams: Dictionary[StringName, AudioStreamWAV] = {}
var _tension := 0.0
var _wind := 0.0
var _flight := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if DisplayServer.get_name() != "headless":
		start()


func start() -> void:
	if _ambience:
		return
	var ambience_bus := _bus(&"Ambience")
	var cue_bus := _bus(&"Signals")
	var sfx_bus := _bus(&"SFX")
	_bus(&"Dialogue")
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = ambience_bus
	_ambience.volume_db = -17.0
	_ambience.stream = _make_breeze()
	add_child(_ambience)
	_ambience.play()
	_score = AudioStreamPlayer.new()
	_score.bus = _bus(&"Music")
	add_child(_score)
	_outgoing = AudioStreamPlayer.new()
	_outgoing.bus = _score.bus
	add_child(_outgoing)
	_play_score()

	for i in range(4):
		var tone := AudioStreamPlayer.new()
		tone.bus = cue_bus
		add_child(tone)
		_tones.append(tone)
		var source := AudioStreamPlayer3D.new()
		source.bus = sfx_bus
		source.unit_size = 2.6
		source.max_distance = 64.0
		add_child(source)
		_spatial.append(source)
	_streams[&"menu"] = _make_note(0.18, 540.0, 780.0, false)
	_streams[&"evidence"] = _make_note(1.04, 388.0, 586.0, false)
	_streams[&"radio"] = _make_note(1.26, 320.0, 670.0, true)
	_streams[&"danger"] = _make_note(0.60, 82.0, 141.0, true)
	_streams[&"rest"] = _make_note(1.10, 236.0, 355.0, false)
	_streams[&"seal"] = _make_note(1.55, 198.0, 298.0, false)
	_streams[&"ending"] = _make_note(2.45, 132.0, 331.0, false)
	_streams[&"wood"] = _make_impact(0.22, 147.0, 451, 0.23)
	_streams[&"gravel"] = _make_impact(0.24, 79.0, 626, 0.74)
	_streams[&"thunder"] = _make_impact(3.30, 38.0, 827, 0.46)
	_streams[&"forest"] = _make_note(0.83, 691.0, 1080.0, true)
	_streams[&"latch"] = _make_impact(0.31, 213.0, 129, 0.42)
	set_process(true)


func set_mood(tension: float, wind: float, flight := false) -> void:
	_tension = clampf(tension, 0.0, 1.0)
	_wind = clampf(wind, 0.0, 1.0)
	_flight = flight


func set_score(cue: StringName, duck := false) -> void:
	_duck = duck
	if cue == _cue or not SCORE.has(cue):
		return
	_cue = cue
	if _score:
		var swap := _outgoing
		_outgoing = _score
		_score = swap
		_play_score()


func _play_score() -> void:
	if not _loaded_score.has(_cue):
		var stream := load("res://assets/score/%s.ogg" % SCORE[_cue]) as AudioStreamOggVorbis
		if stream:
			stream.loop = true
			_loaded_score[_cue] = stream
	var replacement: AudioStream = _loaded_score.get(_cue)
	_score.stream = replacement if replacement else _make_score()
	_score.volume_db = -58.0
	_blend = 0.0
	_score.play()


func play_cue(id: StringName) -> void:
	if not _streams.has(id):
		return
	for tone in _tones:
		if not tone.playing:
			tone.stream = _streams[id]
			tone.volume_db = -14.0 if id == &"menu" else -8.5
			tone.play()
			return


func play_spatial(id: StringName, at: Vector3, db: float, pitch := 1.0) -> void:
	if not _streams.has(id):
		return
	for source in _spatial:
		if not source.playing:
			source.global_position = at
			source.stream = _streams[id]
			source.volume_db = db
			source.pitch_scale = pitch
			source.play()
			return


func follow(delta: float, at: Vector3, speed: float, grounded: bool, wood: bool, flash: float) -> void:
	if not _ambience:
		return
	_at = at
	if grounded and speed > 1.1:
		_stride_distance += speed * delta
		if _stride_distance >= 2.15:
			_stride_distance -= 2.15
			play_spatial(&"wood" if wood else &"gravel", at + Vector3.DOWN * 0.08, -18.0,
				0.89 + 0.22 * absf(sin(at.x * 2.2 + at.z * 3.9)))
	else:
		_stride_distance = 0.0
	if flash > 0.40 and not _heard_flash and _storm_delay < 0.0:
		_storm_delay = 0.85
	_heard_flash = flash > 0.12
	if _storm_delay >= 0.0:
		_storm_delay -= delta
		if _storm_delay < 0.0:
			play_spatial(&"thunder", _at + Vector3(11, 5, -26), -6.0)
	if at.x < -34.0 and at.z > -90.0 and at.z < -35.0 and _wind < 0.65:
		_next_forest_call -= delta
		if _next_forest_call <= 0.0:
			_next_forest_call = 12.0 + 6.0 * absf(sin(at.z * 0.23))
			play_spatial(&"forest", at + Vector3(-12, 7, -5), -26.0, 0.87)


func stop_all() -> void:
	if _ambience:
		_ambience.stop()
	if _score:
		_score.stop()
		_outgoing.stop()
	for tone in _tones:
		tone.stop()
	for source in _spatial:
		source.stop()


func _process(delta: float) -> void:
	_ambience.volume_db = lerpf(_ambience.volume_db, -20.0 + 9.0 * _wind + 4.0 * float(_flight),
		1.0 - exp(-delta * 1.4))
	_ambience.pitch_scale = lerpf(_ambience.pitch_scale, 1.0 - 0.11 * _tension,
		1.0 - exp(-delta * 1.5))
	_duck_gain = lerpf(_duck_gain, 0.35 if _duck else 1.0, 1.0 - exp(-delta * 3.2))
	_blend = minf(_blend + delta / 2.15, 1.0)
	var incoming := sin(_blend * PI * 0.5)
	var outgoing := cos(_blend * PI * 0.5)
	var level := 0.22 * _duck_gain
	_score.volume_linear = maxf(0.001, incoming * level)
	if _outgoing.playing:
		_outgoing.volume_linear = maxf(0.001, outgoing * level)
		if _blend >= 1.0:
			_outgoing.stop()


func _bus(bus_name: StringName) -> StringName:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	return bus_name


func _make_breeze() -> AudioStreamWAV:
	var samples := PackedByteArray()
	var frames := SAMPLE_RATE * BREEZE_SECONDS
	samples.resize(frames * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 64350
	var gust := 0.0
	var deep := 0.0
	for frame in frames:
		var phase := float(frame) / frames * TAU
		var noise := random.randf_range(-1.0, 1.0)
		gust = lerpf(gust, noise, 0.031)
		deep = lerpf(deep, noise, 0.002)
		var curl := 0.53 + sin(phase * 3.0 + 0.9) * 0.19 + sin(phase * 7.0) * 0.12
		var edge := smoothstep(0.0, 0.13, minf(float(frame), float(frames - frame)) / SAMPLE_RATE)
		var air := (gust * 1.28 + deep * 3.21 + noise * 0.016) * curl * edge
		var hum := sin(phase * 378.0) * 0.021 + sin(phase * 579.0) * sin(phase * 2.0) * 0.011
		samples.encode_s16(frame * 2, roundi(clampf(air + hum, -1.0, 1.0) * 32767.0))
	var result := _wave(samples)
	result.loop_mode = AudioStreamWAV.LOOP_FORWARD
	result.loop_end = frames
	return result


func _make_score() -> AudioStreamWAV:
	var samples := PackedByteArray()
	var frames := SAMPLE_RATE * BREEZE_SECONDS
	samples.resize(frames * 2)
	for frame in frames:
		var phase := float(frame) / frames * TAU
		var sway := sin(phase - 1.15) * 0.31 + 0.51
		var floor_tone := sin(phase * 494.0) * 0.13 + sin(phase * 988.0 + sway) * 0.10
		var harmony := sin(phase * 1175.0 + sin(phase * 2.0)) * 0.17 * sway
		var air := sin(phase * 1480.0 + 0.45 * cos(phase)) * 0.086 * (1.0 - sway)
		var bell := sin(phase * 1975.0 + sway * 2.0) * 0.066 * pow(0.5 + 0.5 * cos(phase), 7.0)
		samples.encode_s16(frame * 2, roundi((floor_tone + harmony + air + bell) * 32767.0))
	var result := _wave(samples)
	result.loop_mode = AudioStreamWAV.LOOP_FORWARD
	result.loop_end = frames
	return result


func _make_note(duration: float, low: float, high: float, static_noise: bool) -> AudioStreamWAV:
	var samples := PackedByteArray()
	var frames := roundi(duration * SAMPLE_RATE)
	samples.resize(frames * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 3194
	for frame in frames:
		var t := float(frame) / SAMPLE_RATE
		var end := 1.0 - t / duration
		var fade := minf(1.0, t * 60.0) * end * end
		var phase := t * TAU
		var ring := sin(phase * low + sin(phase * 4.0) * 0.25) * 0.48
		ring += sin(phase * high) * minf(1.0, t * 22.0) * 0.27
		if static_noise:
			ring *= 0.7 + sin(phase * 21.0) * 0.3
			ring += random.randf_range(-0.17, 0.17)
		samples.encode_s16(frame * 2, roundi(clampf(ring * fade, -1.0, 1.0) * 32767.0))
	return _wave(samples)


func _make_impact(length: float, frequency: float, seed_value: int, grit: float) -> AudioStreamWAV:
	var frames := roundi(length * SAMPLE_RATE)
	var samples := PackedByteArray()
	samples.resize(frames * 2)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var low := 0.0
	for i in frames:
		var time := float(i) / SAMPLE_RATE
		var noise := random.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.026 if length > 1.0 else 0.13)
		var envelope := minf(1.0, time * 60.0) * pow(1.0 - time / length, 2.8)
		var tone := sin(time * TAU * (frequency / (1.0 + time * 0.55)))
		var sample := (tone * 0.33 + low * 0.38 + noise * grit * 0.32) * envelope
		samples.encode_s16(i * 2, roundi(sample * 32767))
	return _wave(samples)


func _wave(samples: PackedByteArray) -> AudioStreamWAV:
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = SAMPLE_RATE
	result.data = samples
	return result
