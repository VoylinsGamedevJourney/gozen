class_name TimeManager
extends Node


static func date_to_int(date: Dictionary = Time.get_datetime_dict_from_system()) -> int:
	return int(
		str(date.year) +
		"%02d" % date.month +
		"%02d" % date.day +
		"%02d" % date.hour +
		"%02d" % date.minute)


static func int_to_date(date: int) -> String:
	var str_date: String = str(date)
	return "%s-%s-%s  %s:%s" % [
		str_date.substr(0, 4),
		str_date.substr(4, 2),
		str_date.substr(6, 2),
		str_date.substr(8, 2),
		str_date.substr(10, 2)]
