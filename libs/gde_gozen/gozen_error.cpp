#include "gozen_error.hpp"

void GoZenError::_print(String a_string) {
	UtilityFunctions::printerr(a_string + '!');
}

void GoZenError::print_error(ERROR a_err) {
	switch (a_err) {
		case NO_ERROR:
			_print("No problems detected");
			break;

		case ERR_NOT_OPEN_VIDEO:
			return _print("Video is not open!");
		case ERR_ALREADY_OPEN_VIDEO:
			return _print("Video is already open!");
		case ERR_OPENING_VIDEO:
			return _print("Couldn't open video file!");
		case ERR_INVALID_VIDEO:
			return _print("This video file is not usable!");
		case ERR_INVALID_FRAMERATE:
			return _print("Invalid frame-rate for video found!");

		case ERR_OPENING_AUDIO:
			return _print("Couldn't open audio file!");

		case ERR_NOT_OPEN_RENDERER:
			return _print("Renderer is not open!");
		case ERR_ALREADY_OPEN_RENDERER:
			return _print("Renderer is already open!");
		case ERR_NO_PATH_SET:
			return _print("No path was set!");
		case ERR_NO_CODEC_SET_VIDEO:
			return _print("No video codec was set!");
		case ERR_FAILED_SENDING_FRAME:
			return _print("Something went wrong sending a frame to encoder!");
		case ERR_ENCODING_FRAME:
			return _print("Failed to encode frame!");
		case ERR_FAILED_FLUSH:
			return _print("Failed to flush data to encoder!");
		case ERR_AUDIO_ALREADY_SEND:
			return _print("Audio has already been send to encoder!");
		case ERR_AUDIO_NOT_SEND:
			return _print("Audio needs to be send first for rendering!");
		case ERR_AUDIO_NOT_ENABLED:
			return _print("Audio not enabled for this renderer!");
		case ERR_FAILED_RESAMPLE:
			return _print("Failed to resample audio!");

		case ERR_CREATING_AV_FORMAT_FAILED:
			return _print("Couldn't allocate av format context!");
		case ERR_NO_STREAM_INFO_FOUND:
			return _print("Couldn't find stream info!");
		case ERR_SEEKING:
			return _print("Couldn't seek the stream!");
		case ERR_FAILED_CREATING_STREAM:
			return _print("Couldn't create a new stream!");
		case ERR_COPY_STREAM_PARAMS:
			return _print("Couldn't copy stream params!");
		case ERR_GET_FRAME_BUFFER: 
			return _print("Couldn't get frame data from buffer!");
		case ERR_WRITING_HEADER:
			return _print("Couldn't write video file header!");
			
		case ERR_FAILED_FINDING_VIDEO_DECODER:
			return _print("Couldn't find codec decoder for video!");
		case ERR_FAILED_ALLOC_VIDEO_CODEC:
			return _print("Couldn't allocate codec context for video!");
		case ERR_FAILED_INIT_VIDEO_CODEC:
			return _print("Couldn't initialize video codec context!");
		case ERR_FAILED_OPEN_VIDEO_CODEC:
			return _print("Couldn't open video codec!");

		case ERR_FAILED_FINDING_AUDIO_ENCODER:
			return _print("Couldn't find codec encoder for audio!");
		case ERR_FAILED_ALLOC_AUDIO_CODEC:
			return _print("Couldn't allocate codec context for audio!");
		case ERR_FAILED_OPEN_AUDIO_CODEC:
			return _print("Couldn't open audio codec!");

		case ERR_FAILED_ALLOC_FRAME:
			return _print("Couldn't allocate frame!");
		case ERR_FAILED_ALLOC_PACKET:
			return _print("Couldn't allocate packet!");
		case ERR_FRAME_NOT_WRITABLE:
			return _print("Frame is not writeable!");

		case ERR_CREATING_SWS:
			return _print("Couldn't get/create SWS context!");
		case ERR_SCALING_FAILED:
			return _print("Scaling frame data with SWS failed!");

		case ERR_CREATING_SWR:
			return _print("Couldn't get/create SWR context!");
	}

}
