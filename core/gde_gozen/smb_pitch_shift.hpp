#pragma once

#include <cmath>
#include <cstring>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;


class SMBPitchShift {
	enum { MAX_FRAME_LENGTH = 8192 };

	float gInFIFO[MAX_FRAME_LENGTH] = {};
	float gOutFIFO[MAX_FRAME_LENGTH] = {};
	float gFFTworksp[2 * MAX_FRAME_LENGTH] = {};
	float gLastPhase[MAX_FRAME_LENGTH / 2 + 1] = {};
	float gSumPhase[MAX_FRAME_LENGTH / 2 + 1] = {};
	float gOutputAccum[2 * MAX_FRAME_LENGTH] = {};
	float gAnaFreq[MAX_FRAME_LENGTH] = {};
	float gAnaMagn[MAX_FRAME_LENGTH] = {};
	float gSynFreq[MAX_FRAME_LENGTH] = {};
	float gSynMagn[MAX_FRAME_LENGTH] = {};
	long gRover = 0;

	void smbFft(float* fftBuffer, long fftFrameSize, long sign) {
		float wr, wi, arg, *p1, *p2, temp;
		float tr, ti, ur, ui, *p1r, *p1i, *p2r, *p2i;
		long i, bitm, j, le, le2, k;

		for (i = 2; i < 2 * fftFrameSize - 2; i += 2) {
			for (bitm = 2, j = 0; bitm < 2 * fftFrameSize; bitm <<= 1) {
				if (i & bitm) {
					j++;
				}
				j <<= 1;
			}
			if (i < j) {
				p1 = fftBuffer + i;
				p2 = fftBuffer + j;
				temp = *p1;
				*(p1++) = *p2;
				*(p2++) = temp;
				temp = *p1;
				*p1 = *p2;
				*p2 = temp;
			}
		}
		for (k = 0, le = 2; k < (long)(std::log((double)fftFrameSize) / std::log(2.) + .5); k++) {
			le <<= 1;
			le2 = le >> 1;
			ur = 1.0;
			ui = 0.0;
			arg = Math_PI / (le2 >> 1);
			wr = std::cos(arg);
			wi = sign * std::sin(arg);
			for (j = 0; j < le2; j += 2) {
				p1r = fftBuffer + j;
				p1i = p1r + 1;
				p2r = p1r + le2;
				p2i = p2r + 1;
				for (i = j; i < 2 * fftFrameSize; i += le) {
					tr = *p2r * ur - *p2i * ui;
					ti = *p2r * ui + *p2i * ur;
					*p2r = *p1r - tr;
					*p2i = *p1i - ti;
					*p1r += tr;
					*p1i += ti;
					p1r += le;
					p1i += le;
					p2r += le;
					p2i += le;
				}
				tr = ur * wr - ui * wi;
				ui = ur * wi + ui * wr;
				ur = tr;
			}
		}
	}

  public:
	void PitchShift(float pitchShift, long numSampsToProcess, long fftFrameSize, long osamp, float sampleRate,
					float* indata, float* outdata, int stride) {
		double magn, phase, tmp, window, real, imag;
		double freqPerBin, expct;
		long i, k, qpd, index, inFifoLatency, stepSize, fftFrameSize2;

		fftFrameSize2 = fftFrameSize / 2;
		stepSize = fftFrameSize / osamp;
		freqPerBin = sampleRate / (double)fftFrameSize;
		expct = 2. * Math_PI * (double)stepSize / (double)fftFrameSize;
		inFifoLatency = fftFrameSize - stepSize;
		if (gRover == 0) {
			gRover = inFifoLatency;
		}

		for (i = 0; i < numSampsToProcess; i++) {
			gInFIFO[gRover] = indata[i * stride];
			outdata[i * stride] = gOutFIFO[gRover - inFifoLatency];
			gRover++;

			if (gRover >= fftFrameSize) {
				gRover = inFifoLatency;

				for (k = 0; k < fftFrameSize; k++) {
					window = -.5 * std::cos(2. * Math_PI * (double)k / (double)fftFrameSize) + .5;
					gFFTworksp[2 * k] = gInFIFO[k] * window;
					gFFTworksp[2 * k + 1] = 0.;
				}

				smbFft(gFFTworksp, fftFrameSize, -1);

				for (k = 0; k <= fftFrameSize2; k++) {
					real = gFFTworksp[2 * k];
					imag = gFFTworksp[2 * k + 1];

					magn = 2. * std::sqrt(real * real + imag * imag);
					phase = std::atan2(imag, real);

					tmp = phase - gLastPhase[k];
					gLastPhase[k] = phase;

					tmp -= (double)k * expct;

					qpd = tmp / Math_PI;
					if (qpd >= 0) {
						qpd += qpd & 1;
					} else {
						qpd -= qpd & 1;
					}
					tmp -= Math_PI * (double)qpd;

					tmp = osamp * tmp / (2. * Math_PI);
					tmp = (double)k * freqPerBin + tmp * freqPerBin;

					gAnaMagn[k] = magn;
					gAnaFreq[k] = tmp;
				}

				size_t fftBufferSize = static_cast<size_t>(fftFrameSize) * sizeof(float);
				if (fftFrameSize > MAX_FRAME_LENGTH) {
					UtilityFunctions::printerr(
						"Audio: Invalid FFT frame size for PitchShift. This is a bug, please report.");
					return;
				}
				memset(gSynMagn, 0, fftBufferSize);
				memset(gSynFreq, 0, fftBufferSize);
				for (k = 0; k <= fftFrameSize2; k++) {
					index = k * pitchShift;
					if (index <= fftFrameSize2) {
						gSynMagn[index] += gAnaMagn[k];
						gSynFreq[index] = gAnaFreq[k] * pitchShift;
					}
				}

				for (k = 0; k <= fftFrameSize2; k++) {
					magn = gSynMagn[k];
					tmp = gSynFreq[k];

					tmp -= (double)k * freqPerBin;
					tmp /= freqPerBin;
					tmp = 2. * Math_PI * tmp / osamp;
					tmp += (double)k * expct;

					gSumPhase[k] += tmp;
					phase = gSumPhase[k];

					gFFTworksp[2 * k] = magn * std::cos(phase);
					gFFTworksp[2 * k + 1] = magn * std::sin(phase);
				}

				for (k = fftFrameSize + 2; k < 2 * fftFrameSize; k++) {
					gFFTworksp[k] = 0.;
				}

				smbFft(gFFTworksp, fftFrameSize, 1);

				for (k = 0; k < fftFrameSize; k++) {
					window = -.5 * std::cos(2. * Math_PI * (double)k / (double)fftFrameSize) + .5;
					gOutputAccum[k] += 2. * window * gFFTworksp[2 * k] / (fftFrameSize2 * osamp);
				}
				for (k = 0; k < stepSize; k++) {
					gOutFIFO[k] = gOutputAccum[k];
				}

				memmove(gOutputAccum, gOutputAccum + stepSize, fftBufferSize);
				for (k = 0; k < inFifoLatency; k++) {
					gInFIFO[k] = gInFIFO[k + stepSize];
				}
			}
		}
	}
};
