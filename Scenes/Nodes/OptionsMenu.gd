var options = {
		
	"GAMEPLAY": {
		"BOTPLAY": ["botPlay", "Plays the game for you lmfao.", true],
		"GHOST TAPPING": ["ghostTapping", "Allows you to press keys without losing health.", true],
		"HITSOUNDS": ["hitSounds", "Plays a sound every time you hit a note.", true],
		"STRUM POSITIONS": [null, "", false, "seperator"],
		"DOWNSCROLL": ["downScroll", "Makes the notes move down instead of up.", false],
		"MIDDLESCROLL": ["middleScroll", "Moves your strumline to the middle.", false],
		"ENEMY MIDDLESCROLL": ["middleScrollPreview", "Shows a smaller version of the enemys side on the left.", false],
		"LINUX SPLASH": ["Splash", "Disables the Splash at start-up.", true],
	},

	"APPEARENCE": {
		"HUD RATINGS": ["hudRatings", "Show the ratings on the HUD layer instead of the GAME layer.", true],
		"HUD RATINGS OFFSET": ["hudRatingsOffset", "Changes the on-screen position of the HUD Ratings.", true],
		"CAMERA MOVEMENT": ["cameraMovement", "Moves the camera depending on what notes been hit.", true],
		"BACKGROUND OPACITY": ["backgroundOpacity", "Darkens the game so you can focus on hitting notes. (tryhard)", true, "percent"],
	},

	"CONTROLS": {
		"LEFT": ["left", "", true, "key"],
		"DOWN": ["down", "", true, "key"],
		"UP": ["up", "", true, "key"],
		"RIGHT": ["right", "", true, "key"],
		"SEP1": [null, "", true, "seperator"],
		"CONFIRM": ["confirm", "", true, "key"],
		"CANCEL": ["cancel", "", true, "key"],
		"SEP2": [null, "", false, "seperator"],
		"OFFSET": ["offset", "Changes the offset of the notes.\n(Negative is late, Positive is early)", false, "offset"],
	},

	# 🔥 NEW H-SLICE–STYLE PAGE
	"OPTIMIZATION": {
		"NOTE POOLING": [
			"notePooling",
			"Preallocates notes and reuses them.\nMassively reduces lag and GC spikes.",
			true
		],
		"NOTE POOL SIZE": [
			"notePoolSize",
			"How many notes are preallocated.\nHigher = more RAM, less lag.\n0 = dynamic.",
			true,
			"number"
		],
		"NOTE RECYCLING": [
			"noteRecycling",
			"Reuses notes instead of freeing them.\nH-Slice style optimization.",
			true
		],
		"FAST BOTPLAY": [
			"fastBotplay",
			"Skips animations, events, and heavy logic.\nRemoves botplay lag.",
			true
		],
		"DISABLE GC IN GAME": [
			"disableGC",
			"Disables garbage collection during gameplay.\nGC runs only on load/end.",
			true
		]
	}
}
