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

	for task: Task in tasks:
		if WorkerThreadPool.is_task_completed(task.id):
			error = WorkerThreadPool.wait_for_task_completion(task.id)

			if error:
				printerr("Error with task: ", task.id, " - Error: ", error)
			elif !task.after_task.is_null():
				task.after_task.call()

			tasks.remove_at(tasks.find(task))


func _on_actual_close() -> void:
	mutex.free()


func add_task(todo: Callable, after_todo: Callable) -> void:
	var task: Task = Task.new(WorkerThreadPool.add_task(todo), after_todo)
	tasks.append(task)


class Task:
	var id: int = -1
	var after_task: Callable


	func _init(new_id: int, new_after_task: Callable = Callable()) -> void:
		id = new_id
		after_task = new_after_task


## Timed tasks are for items such as changing effects too quickly, instead of
## creating multiple tasks which cancel each other out with the last one, we
## keep updating the current task.
class TimedTask:
	var task: Callable
	var after_task: Callable
	var time: int


	func _init(new_task: Callable, new_after_task: Callable = Callable()) -> void:
		task = new_task
		after_task = new_after_task
		time = Time.get_ticks_msec() + 200


	func check() -> bool:
		return time <= Time.get_ticks_msec()


	func execute() -> void:
		Threader.tasks.append(Threader.Task.new(
				WorkerThreadPool.add_task(task), after_task))

