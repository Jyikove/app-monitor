#ifndef PROCESS_PROBE_H
#define PROCESS_PROBE_H
#include <stdint.h>
typedef struct {
    int32_t pid, parent_pid;
    uint32_t uid;
    uint64_t start_seconds, start_microseconds, coalition;
    double cpu_seconds;
    uint64_t memory_bytes;
    int metrics_available;
    char executable[4096];
} AMProcess;
int am_snapshot(AMProcess **output);
void am_free(AMProcess *output);
#endif
