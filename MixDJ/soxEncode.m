//
//  soxEncode.m
//  MixDJ
//
//  Created by Jonathan Silverman on 2/24/19.
//  Copyright © 2019 Jonathan Silverman. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "sox.h"

BOOL processWav(NSURL *srcURL, NSURL *dstURL) {
    @try {
        sox_format_t *in, *out; /* input and output files */
        sox_effects_chain_t * chain;
        sox_effect_t * e;
        char *args[10];
        
        // Since the input pcm file is actually raw data, we need to
        // provide the input encoding. Here we assume it's 32 bit floating number PCM
        sox_encodinginfo_t inputEncoding = {
            SOX_ENCODING_FLOAT, // Data type, here we say it's float
            32,                 // Number of bits per data point. Should be 32 in our case.
            0,
            sox_option_default,
            sox_option_default,
            sox_option_default,
            sox_false
        };
        
        sox_encodinginfo_t outputEncoding = {
            SOX_ENCODING_FLOAT, // Data type, here we say it's float
            32,                 // Number of bits per data point. Should be 32 in our case.
            0,
            sox_option_default,
            sox_option_default,
            sox_option_default,
            sox_false
        };
        
        // The output file should have the same encoding as the input.
//        sox_encodinginfo_t outputEncoding = inputEncoding;
        
        sox_signalinfo_t inputSignal = {
            44100, // Sample rate, in our case 44100Hz.
            2,     // Channel number, in our case 2 channels.
            0,     // Precision, bit per sample.
            0,     // Sample number in the file.
            NULL
        };
        
        sox_signalinfo_t outputSignal = {
            44100, // Sample rate, in our case 44100Hz.
            1,     // Channel number, in our case 1 channels.
            0,     // Precision, bit per sample.
            0,     // Sample number in the file.
            NULL
        };
        
        /* All libSoX applications must start by initialising the SoX library */
        assert(sox_init() == SOX_SUCCESS);
        
        /* Open the input file (with default parameters), the file type is raw in our case */
        assert(in = sox_open_read(srcURL.fileSystemRepresentation, &inputSignal, &inputEncoding, "wav"));
        
        /* Open the output file; Now we can specify that the file is in wav format */
        assert(out = sox_open_write(dstURL.fileSystemRepresentation, &outputSignal, &outputEncoding, "raw", NULL, NULL));
        
        /* Create an effects chain; some effects need to know about the input
         * or output file encoding so we provide that information here */
        chain = sox_create_effects_chain(&in->encoding, &out->encoding);
        
        /* The first effect in the effect chain must be something that can source
         * samples; in this case, we use the built-in handler that inputs
         * data from an audio file */
        e = sox_create_effect(sox_find_effect("input"));
        (void)(args[0] = (char *)in), assert(sox_effect_options(e, 1, args) == SOX_SUCCESS);
        /* This becomes the first `effect' in the chain */
        assert(sox_add_effect(chain, e, &in->signal, &in->signal) == SOX_SUCCESS);
        
        /* The last effect in the effect chain must be something that only consumes
         * samples; in this case, we use the built-in handler that outputs
         * data to an audio file */
        e = sox_create_effect(sox_find_effect("output"));
        (void)(args[0] = (char *)out), assert(sox_effect_options(e, 1, args) == SOX_SUCCESS);
        assert(sox_add_effect(chain, e, &out->signal, &out->signal) == SOX_SUCCESS);
        
        /* Flow samples through the effects processing chain until EOF is reached */
        sox_flow_effects(chain, NULL, NULL);
        
        /* All done; tidy up: */
        sox_delete_effects_chain(chain);
        sox_close(out);
        sox_close(in);
        sox_quit();
    } @catch (NSException *exception) {
        NSLog(@"Error when reencode PCM: %@", [exception description]);
        return NO;
    } @finally {
        NSLog(@"New PCM Generation done: %@", dstURL.path);
        return YES;
    }
}

