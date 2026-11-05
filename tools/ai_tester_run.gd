extends SceneTree

# Runs the AI Tester (ai_tester.gd) from the command line, prints the report and
# saves it. No window, no network, no AI service: it costs no tokens.
#
#   godot --headless --path . --script tools/ai_tester_run.gd -- --days=10 --seed=1
#
# Options (all optional):  --days=N (1-200, default 10)   --seed=N (default 1)
#                          --out=PATH (default res://ai_test_report.md)
# Exit code 1 when the verdict is FAIL (a rule was broken), so it also works in CI.
const AiTester := preload("res://ai_tester.gd")

func _initialize() -> void:
	call_deferred("_run")

func _arg(option: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % option): return argument.substr(option.length() + 3)
	return fallback

func _run() -> void:
	var days: int = clampi(int(_arg("days", "10")), 1, 200)
	var seed_number: int = int(_arg("seed", "1"))
	var bot = AiTester.new()
	var results: Array = bot.run_suite(days, seed_number)
	var text: String = bot.report_text(results)
	print(text)
	var out: String = _arg("out", "res://ai_test_report.md")
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		printerr("Could not write the report to %s" % out)
	else:
		file.store_string(text)
		file.close()
		print("\nReport saved to %s" % ProjectSettings.globalize_path(out))
	quit(1 if AiTester.verdict(results) == "FAIL" else 0)
