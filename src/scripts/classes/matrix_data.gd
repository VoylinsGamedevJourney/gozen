class_name MatrixData
extends Resource

enum MATRIX { NULL, TRANSFORM }
enum MATRIX_VAR { NULL, POSITION, SCALE, ROTATION, PIVOT }


@export var matrix_type: EffectParam.PARAM_TYPE
@export var var_type: MATRIX_VAR
@export var matrix: MATRIX
