#include <stdbool.h>
#include <stdio.h>
#include <sysexits.h>
#include <unistd.h>

#include "ckey.h"

#define BANNER "key (C) Copyright 2013 Mark Hills <mark@xwax.org>"
#define NAME "key"

#define RATE 44100

#define ARRAY_SIZE(x) (sizeof(x) / sizeof(*(x)))

//void usage(FILE *f)
//{
//    fputs(BANNER "\n\n", f);
//
//    fprintf(f, "Usage: " NAME " [options]\n"
//        "Analyse the key of incoming audio\n\n"
//        "  -t    Output a traditional key instead of position on circle of fifths\n"
//        "  -h    Display this help message and exit\n\n");
//
//    fprintf(f, "Incoming audio is raw audio on stdin at %dHz, mono, 32-bit float; eg\n"
//        "  $ sox file.mp3 -t raw -r %d -e float -c 1 - | " NAME "\n\n",
//        RATE, RATE);
//
//    fprintf(f, "Output format is a clock position on the circle of fifths (eg. '5A') for\n"
//        "harmonic mixing. If specified, the traditional key name can be output in\n"
//            "an ASCII notation (b: flat; #: sharp; m: minor) eg. 'Abm', 'F#'\n\n");
//
//    fprintf(f, "The key detection used by this program is the work of Ibrahim Sha'ath.\n");
//}

void getKey(const char rawFilePath[], char *name_of_key, size_t nameSize)
{
	void *ckey;
	int key;
	bool trad = false;
    const char *name;

//    for (;;) {
//        int c;
//
//        c = getopt(argc, argv, "th");
//        if (c == -1)
//            break;
//
//        switch (c) {
//        case 't':
//            trad = true;
//            break;
//
//        case 'h':
//            usage(stdout);
//            return 0;
//
//        default:
//            return EX_USAGE;
//        }
//    }

//    argv += optind;
//    argc -= optind;

//    if (argc > 0) {
//        fprintf(stderr, "%s: Too many arguments\n", NAME);
//        return EX_USAGE;
//    }

    FILE *fp;
    
    // can't work without decoding the MP3 to raw 44100 float encoded mono
    fp = fopen(rawFilePath, "r");
    
	ckey = ckey_init(RATE, 1);

	for (;;) {
		float buf[4096];
		ssize_t z;

		z = fread(buf, sizeof *buf, ARRAY_SIZE(buf), fp);
		if (z == -1)
			break;

		ckey_add_audio(ckey, buf, z);

		if (z < ARRAY_SIZE(buf))
			break;
	}

	key = ckey_analyse(ckey);

	if (trad) {
		name = ckey_to_string(key);
	} else {
		name = ckey_to_position(key);
	}

	if (name == NULL)
		printf("Failed to get key for file.");
    
    snprintf(name_of_key, 4, "%s", name);

//    return(name);
}
