#include "ProcessProbe.h"
#include <libproc.h>
#include <sys/proc_info.h>
#include <sys/resource.h>
#include <mach/mach_time.h>
#include <stdlib.h>
#include <unistd.h>

// Optional read-only XNU interface, not exposed in the public SDK. A failed or
// changed interface simply disables coalition attribution; path/ancestry remain.
// https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/proc_info_private.h
struct AMCoalitionInfo { uint64_t ids[2]; uint64_t reserved[3]; };

int am_snapshot(AMProcess **output) {
    *output = NULL;
    int capacity = proc_listallpids(NULL, 0) + 256;
    if (capacity <= 256) return -1;
    pid_t *pids = calloc((size_t)capacity, sizeof(pid_t));
    AMProcess *items = calloc((size_t)capacity, sizeof(AMProcess));
    if (!pids || !items) { free(pids); free(items); return -1; }
    int count = proc_listallpids(pids, capacity * (int)sizeof(pid_t));
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    double seconds_per_tick = (double)timebase.numer / timebase.denom / 1e9;
    int used = 0;
    for (int i = 0; i < count && i < capacity; i++) {
        if (pids[i] <= 1) continue;
        struct proc_bsdinfo bsd = {0};
        if (proc_pidinfo(pids[i], PROC_PIDTBSDINFO, 0, &bsd, sizeof(bsd)) != sizeof(bsd)) continue;
        if (bsd.pbi_uid != getuid()) continue;
        AMProcess *item = &items[used++];
        item->pid = pids[i]; item->parent_pid = bsd.pbi_ppid; item->uid = bsd.pbi_uid;
        item->start_seconds = bsd.pbi_start_tvsec; item->start_microseconds = bsd.pbi_start_tvusec;
        proc_pidpath(pids[i], item->executable, sizeof(item->executable));
        struct rusage_info_v4 usage = {0};
        if (proc_pid_rusage(pids[i], RUSAGE_INFO_V4, (rusage_info_t *)&usage) == 0) {
            item->cpu_seconds = ((double)usage.ri_user_time + (double)usage.ri_system_time) * seconds_per_tick;
            item->memory_bytes = usage.ri_phys_footprint;
            item->metrics_available = 1;
        }
        struct AMCoalitionInfo coalition = {0};
        if (proc_pidinfo(pids[i], 20, 0, &coalition, sizeof(coalition)) == sizeof(coalition)) {
            item->coalition = coalition.ids[1]; // jetsam/app coalition, not resource coalition
        }
    }
    free(pids); *output = items; return used;
}
void am_free(AMProcess *output) { free(output); }
