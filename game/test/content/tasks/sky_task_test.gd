extends GdUnitTestSuite
## The sky task (Concept/v0.5/05, Kindle Hollow) holds everything a task must (TaskCheck): its reference passes, its starter and
## its Builder's start do not, each block answer passes its stage, and no text gives the answer away.


func test_the_sky_task_holds_together() -> void:
	var found := TaskCheck.problems("sky")
	assert_array(found).override_failure_message("\n".join(found)).is_empty()
