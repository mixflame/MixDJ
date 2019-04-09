//
//  bpm.h
//  MixDJ
//
//  Created by Jonathan Silverman on 2/23/19.
//  Copyright © 2019 Jonathan Silverman. All rights reserved.
//

#ifndef bpm_h
#define bpm_h

#include <stdio.h>

double scan_for_bpm(float nrg[], size_t len,
                    double slowest, double fastest,
                    unsigned int steps,
                    unsigned int samples,
                    FILE *file);

double interval_to_bpm(double interval);

double bpm_to_interval(double bpm);

double autodifference(float nrg[], size_t len, double interval);

static double sample(float nrg[], size_t len, double offset);

float processFile(const char fileUrl[]);

#endif /* bpm_h */
