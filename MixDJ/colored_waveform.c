//
//  colored_waveform.c
//  MixDJ
//
//  Created by Jonathan Silverman on 3/14/19.
//  Copyright © 2019 Jonathan Silverman. All rights reserved.
//

#include "colored_waveform.h"
#include "fftw3.h"
#include <math.h>
#include "sndfile.h"

//int N = 1024;

struct color {
    unsigned char R;
    unsigned char G;
    unsigned char B;
};

// helper function to apply a windowing function to a frame of samples
void calcWindow(double* in, double* out, int size) {
    for (int i = 0; i < size; i++) {
        double multiplier = 0.5 * (1 - cos(2*M_PI*i/(size - 1)));
        out[i] = multiplier * in[i];
    }
}

// helper function to compute FFT
void fft(double* samples, fftw_complex* out, int size) {

    fftw_plan p;
    p = fftw_plan_dft_r2c_1d(size, samples, out, FFTW_ESTIMATE);
    
    fftw_execute(p);
    fftw_destroy_plan(p);
    
}

// find the index of array element with the highest absolute value
// probably want to take some kind of moving average of buf[i]^2
// and return the maximum found
double maxFreqIndex(fftw_complex* buf, int size, float fS) {
    double max_freq = 0;
    double last_magnitude = 0;
    for(int i = 0; i < size / 2; i++) {
        double freq = i * fS / size;
//        printf("freq: %f\n", freq);
//        double magnitude = sqrt(buf[i][0]*buf[i][0] + buf[i][1]*buf[i][1]);
        double magnitude = hypot(buf[i][0], buf[i][1]);
        if(magnitude > last_magnitude)
            max_freq = freq;
        last_magnitude = magnitude;
        
    }
    return max_freq;
}
//
//// map a frequency to a color, red = lower freq -> violet = high freq
int * freqToColor(int x) {
    unsigned int red   = (x & 0x00ff0000) >> 16;
    unsigned int green = (x & 0x0000ff00) >> 8;
    unsigned int blue  = (x & 0x000000ff);
    static int color[3];
    color[0] = red;
    color[1] = green;
    color[2] = blue;
    return color;
}

void generateWaveformColors(const char path[]) {
    printf("Generating waveform colors\n");
    SNDFILE     *infile = NULL;
    SF_INFO     sfinfo;
    
    infile = sf_open(path, SFM_READ, &sfinfo);
    
    
    sf_count_t numSamples = sfinfo.frames;

    // sample rate
    float fS = 44100;
    
//    float songLengLengthSeconds = numSamples / fS;
    
//    printf("seconds: %f", songLengLengthSeconds);

    // size of frame for analysis, you may want to play with this
    float frameMsec = 20;

    // samples in a frame
    int frameSamples = (int)(fS / (frameMsec * 1000));

    // how much overlap each frame, you may want to play with this one too
    int frameOverlap = (frameSamples / 2);

    // color to use for each frame
    int * outColors[(numSamples / frameOverlap) + 1];

    // scratch buffers
    double* tmpWindow;
    fftw_complex* tmpFFT;
    
    tmpWindow = (double*) fftw_malloc(sizeof(double) * frameSamples);
    tmpFFT = (fftw_complex*) fftw_malloc(sizeof(fftw_complex) * frameSamples);

    printf("Processing waveform for colors\n");
    for (int i = 0, outptr = 0; i < numSamples; i += frameOverlap, outptr++)
    {
        double inSamples[frameSamples];
        
        sf_read_double(infile, inSamples, frameSamples);
        
        // window another frame for FFT
        calcWindow(inSamples, tmpWindow, frameSamples);

        // compute the FFT on the next frame
        fft(tmpWindow, tmpFFT, frameSamples);

        // which frequency is the highest?
        double freqIndex = maxFreqIndex(tmpFFT, frameSamples, fS);

//        printf("%i: ", i);
//        printf("Max freq: %f\n", freqIndex);
        // map to color
        outColors[outptr] = freqToColor(freqIndex);
        
        printf("r: %i ", outColors[outptr][0]);
        printf("g: %i ", outColors[outptr][1]);
        printf("b: %i\n", outColors[outptr][2]);
    }
    printf("Done.");
    sf_close (infile);

}
