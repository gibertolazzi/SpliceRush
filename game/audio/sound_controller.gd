class_name SoundController
extends Node

const MIX_RATE: int = 22050

var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer

var stream_hit: AudioStreamWAV
var stream_kill: AudioStreamWAV
var stream_steal_stinger: AudioStreamWAV
var stream_abom_alarm: AudioStreamWAV
var stream_dash: AudioStreamWAV
var stream_equip_pop: AudioStreamWAV
var stream_music_loop: AudioStreamWAV

var last_played_stinger: StringName = &""
var current_music_mode: StringName = &"normal"
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 20261109
	_setup_audio_buses()
	_synthesize_all_streams()
	_setup_players()

func _setup_audio_buses() -> void:
	# Ensure Music and SFX buses exist and route to Master using linear_to_db (audio-design & godot-audio skills)
	if AudioServer.get_bus_index(&"Music") == -1:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, &"Music")
		AudioServer.set_bus_send(idx, &"Master")
		AudioServer.set_bus_volume_db(idx, linear_to_db(0.45))
	if AudioServer.get_bus_index(&"SFX") == -1:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, &"SFX")
		AudioServer.set_bus_send(idx, &"Master")
		AudioServer.set_bus_volume_db(idx, linear_to_db(0.85))

func _synthesize_all_streams() -> void:
	stream_hit = _make_synth_wav(0.09, [260.0, 110.0], true, false)
	stream_kill = _make_synth_wav(0.24, [420.0, 280.0, 140.0], true, false)
	# Signature memeable 4-note ascending power arpeggio stinger on part steal!
	stream_steal_stinger = _make_synth_wav(0.42, [330.0, 440.0, 554.37, 659.25, 880.0], false, false)
	stream_abom_alarm = _make_synth_wav(0.55, [220.0, 440.0, 330.0, 660.0], false, false)
	stream_dash = _make_synth_wav(0.14, [180.0, 520.0], true, false)
	stream_equip_pop = _make_synth_wav(0.12, [520.0, 780.0, 1040.0], false, false)
	stream_music_loop = _make_synth_wav(1.60, [110.0, 130.81, 146.83, 164.81, 146.83, 130.81, 110.0, 98.0], false, true)

func _make_synth_wav(duration_sec: float, freqs: Array[float], add_noise: bool, loop: bool) -> AudioStreamWAV:
	var sample_count: int = maxi(1, int(duration_sec * float(MIX_RATE)))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase: float = 0.0
	var seg_count: int = maxi(1, freqs.size())
	for i: int in range(sample_count):
		var t_norm: float = float(i) / float(sample_count)
		var seg_idx: int = mini(seg_count - 1, int(t_norm * float(seg_count)))
		var f: float = float(freqs[seg_idx])
		phase += TAU * f / float(MIX_RATE)
		# Punchy square-ish + sine harmonic synth wave
		var wave: float = sin(phase) * 0.65 + (0.35 if sin(phase * 2.0) >= 0.0 else -0.35)
		if add_noise:
			wave = wave * 0.72 + _rng.randf_range(-0.28, 0.28) * (1.0 - t_norm)
		var env: float = 1.0
		if not loop:
			env = clampf(1.0 - pow(t_norm, 1.6), 0.0, 1.0)
			if t_norm < 0.04:
				env *= (t_norm / 0.04)
		var sample_i16: int = clampi(int(wave * env * 14000.0), -32767, 32767)
		data.encode_s16(i * 2, sample_i16)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = sample_count
	return wav

func _setup_players() -> void:
	for i: int in range(6):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = &"SFX"
		add_child(p)
		sfx_players.append(p)

	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = &"Music"
	music_player.stream = stream_music_loop
	add_child(music_player)
	if DisplayServer.get_name() != "headless":
		music_player.play()

func play_hit_sfx() -> void:
	last_played_stinger = &"hit"
	_play_on_pool(stream_hit, _rng.randf_range(0.92, 1.10), -4.0)

func play_kill_sfx() -> void:
	last_played_stinger = &"kill"
	_play_on_pool(stream_kill, _rng.randf_range(0.95, 1.05), -1.0)

func play_steal_stinger() -> void:
	last_played_stinger = &"steal_stinger"
	_play_on_pool(stream_steal_stinger, 1.0, 0.0)

func play_abomination_stinger() -> void:
	last_played_stinger = &"abomination_alarm"
	_play_on_pool(stream_abom_alarm, 1.0, 1.0)
	set_music_intensity(&"abomination")

func play_dash_sfx() -> void:
	last_played_stinger = &"dash"
	_play_on_pool(stream_dash, _rng.randf_range(0.95, 1.08), -3.0)

func play_equip_sfx() -> void:
	last_played_stinger = &"equip"
	_play_on_pool(stream_equip_pop, _rng.randf_range(0.96, 1.05), -2.0)

func play_pickup_pop() -> void:
	play_equip_sfx()

func set_music_intensity(mode: StringName) -> void:
	current_music_mode = mode
	if music_player == null:
		return
	match mode:
		&"abomination":
			music_player.pitch_scale = 1.22
		&"frenzy":
			music_player.pitch_scale = 1.14
		_:
			music_player.pitch_scale = 1.0

func _play_on_pool(stream: AudioStream, pitch: float, vol_db: float) -> void:
	if stream == null or sfx_players.is_empty():
		return
	for p: AudioStreamPlayer in sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.volume_db = vol_db
			if DisplayServer.get_name() != "headless":
				p.play()
			return
	# Fallback to first player if all busy
	var p0: AudioStreamPlayer = sfx_players[0]
	p0.stream = stream
	p0.pitch_scale = pitch
	p0.volume_db = vol_db
	if DisplayServer.get_name() != "headless":
		p0.play()
