extends Node


var timed_tasks: Dictionary[int, TimedTask] = {} # [clip_id, Task]
var tasks: Array[Task] = []
var mutex: Mutex = Mutex.new()
var error: int = -1



func _process(_delta: float) -> void:
	for i: int in timed_tasks.keys():
		if timed_tasks[i].check():
			timed_tasks[i].execute()
			if !timed_tasks.erase(i):
				Toolbox.print_erase_error()

	for l_task: Task in tasks:
		if WorkerThreadPool.is_task_completed(l_task.id):
			error = WorkerThreadPool.wait_for_task_completion(l_task.id)

			if error:
				printerr("Error with task: ", l_task.id, " - Error: ", error)
			elif !l_task.after_task.is_null():
				l_task.after_task.call()

			tasks.remove_at(tasks.find(l_task))


class Task:
	var id: int = -1
	var after_task: Callable


	func _init(a_id: int, a_after_task: Callable = Callable()) -> void:
		id = a_id
		after_task = a_after_task


## Timed tasks are for items such as changing effects to quickly, instead of
## creating multiple tasks which cancel each other out with the last one, we
## keep updating the current task 
class TimedTask:
	var task: Callable
	var after_task: Callable
	var time: int


	func _init(a_task: Callable, a_after_task: Callable = Callable()) -> void:
		task = a_task
		after_task = a_after_task
		time = Time.get_ticks_msec() + 200


	func check() -> bool:
		return time <= Time.get_ticks_msec()


	func execute() -> void:
		Threader.tasks.append(Threader.Task.new(
				WorkerThreadPool.add_task(task), after_task))

