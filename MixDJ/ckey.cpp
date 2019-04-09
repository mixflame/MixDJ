/*
 * Simple C wrapper to libKeyFinder
 *
 * Writing option parsing and file I/O tends to come out "C style"
 * anyway and the result is usually a mix of C++ and C
 * concepts. Instead, wrap the C++ library to present a simple C
 * interface as a bridge -- all the nasty stuff is in this file.
 */

#include <stdlib.h>

#include "ckey.h"
#include "keyfinder.h"

/*
 * Initialise key detection contect
 *
 * Return: handle to context
 */

void* ckey_init(int rate, int channels)
{
	KeyFinder::AudioData *a = new KeyFinder::AudioData();

	a->setFrameRate(rate);
	a->setChannels(channels);

	return static_cast<void*>(a);
}

/*
 * Finish up with key detection context
 */

void ckey_clear(void *c)
{
	KeyFinder::AudioData *a = static_cast<KeyFinder::AudioData*>(c);
	delete a;
}

/*
 * Register some audio for key detection. The len is the number of
 * frames ie. there is one float for each channel.
 */

void ckey_add_audio(void *c, const float *buf, size_t len)
{
	KeyFinder::AudioData *a = static_cast<KeyFinder::AudioData*>(c);
	size_t n, total;

	total = a->getSampleCount();

	len *= a->getChannels();
	a->addToSampleCount(len);

	for (n = 0; n < len; n++)
		a->setSample(total + n, buf[n]);
}

/*
 * Perform key analysis
 *
 * Return: numeric representation of key
 */

int ckey_analyse(void *c)
{
	KeyFinder::AudioData *a = static_cast<KeyFinder::AudioData*>(c);
	KeyFinder::Parameters p;
	KeyFinder::KeyFinder k;

	KeyFinder::KeyDetectionResult r = k.findKey(*a, p);
	return r.globalKeyEstimate;
}

/*
 * Translate keys to clock positions on the circle of fifths,
 * where A is minor and B is major.
 */

const char* ckey_to_position(int key)
{
	switch (key) {
	case KeyFinder::A_MAJOR:	return "11B";
	case KeyFinder::A_MINOR:	return "8A";
	case KeyFinder::B_FLAT_MAJOR:	return "6B";
	case KeyFinder::B_FLAT_MINOR:	return "3A";
	case KeyFinder::B_MAJOR:	return "1B";
	case KeyFinder::B_MINOR:	return "10A";
	case KeyFinder::C_MAJOR:	return "8B";
	case KeyFinder::C_MINOR:	return "5A";
	case KeyFinder::D_FLAT_MAJOR:	return "3B";
	case KeyFinder::D_FLAT_MINOR:	return "12A";
	case KeyFinder::D_MAJOR:	return "10B";
	case KeyFinder::D_MINOR:	return "7A";
	case KeyFinder::E_FLAT_MAJOR:	return "5B";
	case KeyFinder::E_FLAT_MINOR:	return "2A";
	case KeyFinder::E_MAJOR:	return "12B";
	case KeyFinder::E_MINOR:	return "9A";
	case KeyFinder::F_MAJOR:	return "7B";
	case KeyFinder::F_MINOR:	return "4A";
	case KeyFinder::G_FLAT_MAJOR:	return "2B";
	case KeyFinder::G_FLAT_MINOR:	return "11A";
	case KeyFinder::G_MAJOR:	return "9B";
	case KeyFinder::G_MINOR:	return "6A";
	case KeyFinder::A_FLAT_MAJOR:	return "4B";
	case KeyFinder::A_FLAT_MINOR:	return "1A";
	default:			return NULL;
	}
}

const char* ckey_to_string(int key)
{
	switch (key) {
	case KeyFinder::A_MAJOR:	return "A";
	case KeyFinder::A_MINOR:	return "Am";
	case KeyFinder::B_FLAT_MAJOR:	return "Bb";
	case KeyFinder::B_FLAT_MINOR:	return "Bbm";
	case KeyFinder::B_MAJOR:	return "B";
	case KeyFinder::B_MINOR:	return "Bm";
	case KeyFinder::C_MAJOR:	return "C";
	case KeyFinder::C_MINOR:	return "Cm";
	case KeyFinder::D_FLAT_MAJOR:	return "Db";
	case KeyFinder::D_FLAT_MINOR:	return "Dbm";
	case KeyFinder::D_MAJOR:	return "D";
	case KeyFinder::D_MINOR:	return "Dm";
	case KeyFinder::E_FLAT_MAJOR:	return "Eb";
	case KeyFinder::E_FLAT_MINOR:	return "Ebm";
	case KeyFinder::E_MAJOR:	return "E";
	case KeyFinder::E_MINOR:	return "Em";
	case KeyFinder::F_MAJOR:	return "F";
	case KeyFinder::F_MINOR:	return "Fm";
	case KeyFinder::G_FLAT_MAJOR:	return "Gb";
	case KeyFinder::G_FLAT_MINOR:	return "Gbm";
	case KeyFinder::G_MAJOR:	return "G";
	case KeyFinder::G_MINOR:	return "Gm";
	case KeyFinder::A_FLAT_MAJOR:	return "Ab";
	case KeyFinder::A_FLAT_MINOR:	return "Abm";
	default:			return NULL;
	}
}
