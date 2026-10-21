extends GdUnitTestSuite
## The sacks task (Kindle Hollow, level 0) holds everything a task must (TaskCheck): its reference passes, its starter and
## its Builder's start do not, each block answer passes its stage, and no text gives the answer away.


func test_the_sacks_task_holds_together() -> void:
	var found := TaskCheck.problems("sacks")
	assert_array(found).override_failure_message("\n".join(found)).is_empty()
