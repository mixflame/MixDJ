#ifndef CKEY_H
#define CKEY_H

#ifdef __cplusplus
extern "C" {
#endif

void *ckey_init(int rate, int channels);
void ckey_clear(void *c);

void ckey_add_audio(void *c, const float *buf, size_t len);
int ckey_analyse(void *c);

const char* ckey_to_position(int key);
const char* ckey_to_string(int key);

#ifdef __cplusplus
}
#endif

#endif
