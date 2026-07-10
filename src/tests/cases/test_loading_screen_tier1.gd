extends RefCounted

# Loading screen contracts for Priority 3 polish.

var tree: SceneTree = null
var failed: bool = false
var fail_reason: String = ""

func fail(reason: String) -> void:
	if failed:
		return
	failed = true
	fail_reason = reason

func assert_true(condition: bool, msg: String) -> void:
	if not condition:
		fail("Assertion failed: %s (Expected true, got false)" % msg)

func assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		fail("Assertion failed: %s (Expected %s, got %s)" % [msg, str(expected), str(actual)])

func assert_not_null(val: Variant, msg: String) -> void:
	if val == null:
		fail("Assertion failed: %s (Expected non-null value)" % msg)

func test_loading_screen_scene_has_priority3_hooks() -> void:
	var packed := load("res://src/ui/LoadingScreen.tscn") as PackedScene
	assert_not_null(packed, "LoadingScreen scene must load")
	if packed == null:
		return
	var screen := packed.instantiate() as LoadingScreen
	assert_not_null(screen, "LoadingScreen scene must instantiate")
	if screen == null:
		return

	var title := screen.get_node_or_null("Panel/CenterBox/TitleLabel") as Label
	var story := screen.get_node_or_null("Panel/CenterBox/StoryLabel") as Label
	var progress := screen.get_node_or_null("Panel/CenterBox/ProgressMargin/ProgressBar") as ProgressBar
	var percent := screen.get_node_or_null("Panel/CenterBox/PercentLabel") as Label
	var tip := screen.get_node_or_null("Panel/CenterBox/TipLabel") as Label

	assert_not_null(title, "Loading title label must exist")
	assert_not_null(story, "Loading story label must exist")
	assert_not_null(progress, "Loading progress bar must exist")
	assert_not_null(percent, "Loading percent label must exist")
	assert_not_null(tip, "Loading tip label must exist")

	screen.queue_free()

func test_loading_screen_update_ui_updates_progress_and_percent() -> void:
	var packed := load("res://src/ui/LoadingScreen.tscn") as PackedScene
	var screen := packed.instantiate() as LoadingScreen
	var progress := screen.get_node_or_null("Panel/CenterBox/ProgressMargin/ProgressBar") as ProgressBar
	var percent := screen.get_node_or_null("Panel/CenterBox/PercentLabel") as Label
	var tip := screen.get_node_or_null("Panel/CenterBox/TipLabel") as Label
	screen._progress_bar = progress
	screen._percent_label = percent
	screen._tip_label = tip

	screen.call("_update_ui", 42.0)

	assert_eq(progress.value, 42.0, "Loading progress should reflect the threaded load percentage")
	assert_eq(percent.text, "42%", "Loading percent label should show an integer percentage")

	screen.queue_free()

func test_loading_screen_tips_and_styles_match_priority3_direction() -> void:
	assert_eq(
		LoadingScreen.TIPS[0],
		"Có những lối mòn chỉ hiện ra với người dám bước qua màn sương đầu rừng.",
		"Loading tips should use the new fairy-tale voice"
	)
	var packed := load("res://src/ui/LoadingScreen.tscn") as PackedScene
	var screen := packed.instantiate() as LoadingScreen
	var progress := screen.get_node_or_null("Panel/CenterBox/ProgressMargin/ProgressBar") as ProgressBar
	var story := screen.get_node_or_null("Panel/CenterBox/StoryLabel") as Label

	assert_not_null(progress.get_theme_stylebox("background"), "Loading progress should have a themed track style")
	assert_not_null(progress.get_theme_stylebox("fill"), "Loading progress should have a themed fill style")
	assert_true(story.text.contains("Thạch Sanh"), "Loading story copy should reference the game's fairy-tale identity")

	screen.queue_free()
