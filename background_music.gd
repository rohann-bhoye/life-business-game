extends RefCounted

# One continuous background music player for the whole game. It lives under the
# scene tree root, so the calm nature track keeps playing smoothly from the lobby
# into the game, through pause and sleep, and back (scene changes never restart it).
const TRACK := "res://assets/audio/generated/music_nature.wav"
const VOLUME_DB := -12.0
static var player: AudioStreamPlayer

static func ensure(tree: SceneTree) -> AudioStreamPlayer:
	if not is_instance_valid(player):
		player = tree.root.get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "BackgroundMusic"
		player.stream = load(TRACK)
		player.volume_db = VOLUME_DB
		player.bus = AudioServer.get_bus_name(preload("res://game_settings.gd").music_bus())
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		# The root may be busy adding the new scene, so join it at the end of the frame.
		tree.root.add_child.call_deferred(player)
		if DisplayServer.get_name() != "headless": player.ready.connect(player.play, CONNECT_ONE_SHOT)
	elif not player.playing and player.is_inside_tree() and DisplayServer.get_name() != "headless":
		player.play()
	return player
