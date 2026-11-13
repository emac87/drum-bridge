#include "DBKernel.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int fails = 0;
#define CHECK(c, msg) do { if (!(c)) { printf("FAIL: %s\n", msg); fails++; } } while (0)
int main(void) {
    DBKernel *k = db_kernel_create();
    DBTables t; db_tables_init(&t);
    // ch10 note 37 (pad 2) -> 38 (snare); ch10 note 40 -> drop; note 42 pedal hi-hat
    db_tables_set_route(&t, 9, 37, 38, 0);
    db_tables_set_route(&t, 9, 40, DB_ROUTE_DROP, 0);
    db_tables_set_route(&t, 9, 42, DB_ROUTE_HIHAT, 0);
    db_tables_set_hihat(&t, 0, 0, 42); db_tables_set_hihat(&t, 0, 1, 23); db_tables_set_hihat(&t, 0, 2, 46);
    t.outChannel = 0; // force ch1
    db_kernel_set_tables(k, &t);
    uint8_t out[8]; int n;
    uint8_t on[3] = {0x99, 37, 100};
    n = db_kernel_process(k, on, 3, out);
    CHECK(n == 3 && out[0] == 0x90 && out[1] == 38 && out[2] == 100, "remap note on + channel");
    // change tables while note held: note off must still release 38
    db_tables_set_route(&t, 9, 37, 50, 0); db_kernel_set_tables(k, &t);
    uint8_t off[3] = {0x89, 37, 0};
    n = db_kernel_process(k, off, 3, out);
    CHECK(n == 3 && out[0] == 0x80 && out[1] == 38, "note off releases original");
    uint8_t on0[3] = {0x99, 37, 0}; // vel 0 with nothing sounding
    n = db_kernel_process(k, on0, 3, out); CHECK(n == 0, "stray note off dropped");
    uint8_t d[3] = {0x99, 40, 90}; n = db_kernel_process(k, d, 3, out); CHECK(n == 0, "drop");
    uint8_t p[3] = {0x99, 60, 90}; n = db_kernel_process(k, p, 3, out); CHECK(n == 3 && out[1] == 60, "pass");
    // hi-hat zones
    uint8_t cc[3] = {0xB9, 4, 127}; n = db_kernel_process(k, cc, 3, out); CHECK(n == 3 && out[0] == 0xB0 && out[1] == 4, "pedal cc forwarded");
    uint8_t hh[3] = {0x99, 42, 80}; n = db_kernel_process(k, hh, 3, out); CHECK(out[1] == 42, "closed");
    cc[2] = 60; db_kernel_process(k, cc, 3, out); n = db_kernel_process(k, hh, 3, out); CHECK(out[1] == 23, "half");
    cc[2] = 0; db_kernel_process(k, cc, 3, out); n = db_kernel_process(k, hh, 3, out); CHECK(out[1] == 46, "open");
    // velocity curve
    db_tables_set_velocity(&t, 1.0, 20); CHECK(t.velLUT[1] >= 20 && t.velLUT[127] == 127 && t.velLUT[64] > 64, "louder curve");
    db_tables_set_velocity(&t, -1.0, 1); CHECK(t.velLUT[64] < 64 && t.velLUT[1] >= 1, "softer curve");
    // audition + events
    db_kernel_audition(k, 36, 100, 1);
    n = db_kernel_pop_audition(k, out); CHECK(n == 3 && out[0] == 0x90 && out[1] == 36, "audition");
    DBEvent ev[64]; n = db_kernel_read_events(k, ev, 64); CHECK(n >= 5, "events logged");
    // fuzz
    srand(1);
    for (int i = 0; i < 200000; i++) {
        uint8_t m[3] = {(uint8_t)(0x80 | (rand() & 0x7F)), (uint8_t)(rand() & 0xFF), (uint8_t)(rand() & 0xFF)};
        int len = 1 + rand() % 3;
        n = db_kernel_process(k, m, len, out);
        if (n < 0 || n > 3) { CHECK(0, "fuzz length"); break; }
        if ((i & 1023) == 0) db_kernel_read_events(k, ev, 64);
    }
    uint8_t all[3 * 2048]; n = db_kernel_all_notes_off(k, all, 2048);
    CHECK(db_kernel_all_notes_off(k, all, 2048) == 0, "all notes off clears");
    db_kernel_destroy(k);
    printf(fails ? "%d FAILED\n" : "ALL PASS\n", fails);
    return fails != 0;
}
