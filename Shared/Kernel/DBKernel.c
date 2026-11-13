#if !defined(__APPLE__)
#define _POSIX_C_SOURCE 200809L
#endif
#include "DBKernel.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

#define RING 512   // activity log (power of two)
#define AQ   64    // audition queue (power of two)

struct DBKernel {
    DBTables tables[2];
    _Atomic int active;         // slot the render thread should use
    _Atomic int ack;            // slot the render thread last used

    // render-thread state
    uint8_t pedal[16];          // last hi-hat pedal value per input channel
    uint8_t sounding[16][128];  // outNote + 1 for notes held on input ch/note (0 = none)
    uint8_t soundCh[16][128];   // output channel of that held note

    // activity log: render writes, UI reads
    DBEvent ring[RING];
    _Atomic uint32_t ringHead, ringTail;

    // audition: UI writes, render reads
    uint8_t aq[AQ][3];
    _Atomic uint32_t aqHead, aqTail;
};

void db_tables_init(DBTables *t) {
    memset(t, 0, sizeof(*t));
    memset(t->route, DB_ROUTE_PASS, sizeof(t->route));
    memset(t->hhOut, DB_ROUTE_DROP, sizeof(t->hhOut));
    t->hhCC = 4;
    t->hhClosedAt = 90;
    t->hhHalfAt = 40;
    t->pedalOutCC = 4;
    t->outChannel = DB_KEEP_CHANNEL;
    t->inChannel = DB_ANY_CHANNEL;
    db_tables_set_velocity(t, 0.0, 1);
}

void db_tables_set_velocity(DBTables *t, double curve, int minVel) {
    if (curve < -1) curve = -1;
    if (curve > 1) curve = 1;
    if (minVel < 1) minVel = 1;
    if (minVel > 127) minVel = 127;
    double gamma = pow(3.0, -curve);   // curve 1 -> 1/3 (louder), -1 -> 3 (softer)
    t->velLUT[0] = 0;
    for (int v = 1; v < 128; v++) {
        double x = (double)v / 127.0;
        double y = pow(x, gamma);
        int o = (int)lround(minVel + y * (127 - minVel));
        if (o < minVel) o = minVel;
        if (o > 127) o = 127;
        t->velLUT[v] = (uint8_t)o;
    }
}

void db_tables_set_route(DBTables *t, int channel, int note, uint8_t route, uint8_t hhGroup) {
    if (channel < 0 || channel > 15 || note < 0 || note > 127) return;
    t->route[channel][note] = route;
    t->hhGroup[channel][note] = hhGroup % DB_HH_GROUPS;
}

void db_tables_set_hihat(DBTables *t, int group, int zone, uint8_t note) {
    if (group < 0 || group >= DB_HH_GROUPS || zone < 0 || zone > 2) return;
    t->hhOut[group][zone] = note;
}

uint8_t db_tables_get_route(const DBTables *t, int channel, int note) {
    if (channel < 0 || channel > 15 || note < 0 || note > 127) return DB_ROUTE_DROP;
    return t->route[channel][note];
}

DBKernel *db_kernel_create(void) {
    DBKernel *k = (DBKernel *)calloc(1, sizeof(DBKernel));
    if (!k) return NULL;
    db_tables_init(&k->tables[0]);
    db_tables_init(&k->tables[1]);
    atomic_init(&k->active, 0);
    atomic_init(&k->ack, 0);
    atomic_init(&k->ringHead, 0);
    atomic_init(&k->ringTail, 0);
    atomic_init(&k->aqHead, 0);
    atomic_init(&k->aqTail, 0);
    return k;
}

void db_kernel_destroy(DBKernel *k) { free(k); }

static void sleep_ms(int ms) {
    struct timespec ts = { 0, (long)ms * 1000000L };
    nanosleep(&ts, NULL);
}

void db_kernel_set_tables(DBKernel *k, const DBTables *t) {
    int cur = atomic_load_explicit(&k->active, memory_order_acquire);
    // Wait (briefly) until the render thread has stopped using the other slot.
    // If audio isn't running, ack never moves; give up after ~20 ms - nobody is reading then.
    for (int i = 0; i < 20 && atomic_load_explicit(&k->ack, memory_order_acquire) != cur; i++) sleep_ms(1);
    int next = 1 - cur;
    k->tables[next] = *t;
    atomic_store_explicit(&k->active, next, memory_order_release);
}

static inline const DBTables *tables_for_render(DBKernel *k) {
    int idx = atomic_load_explicit(&k->active, memory_order_acquire);
    atomic_store_explicit(&k->ack, idx, memory_order_release);
    return &k->tables[idx];
}

static inline void log_event(DBKernel *k, uint8_t kind, uint8_t ch, uint8_t inNote, uint8_t outNote, uint8_t vel) {
    uint32_t h = atomic_load_explicit(&k->ringHead, memory_order_relaxed);
    uint32_t tl = atomic_load_explicit(&k->ringTail, memory_order_acquire);
    if (h - tl >= RING) return; // full: drop the log entry, never the MIDI
    DBEvent *e = &k->ring[h & (RING - 1)];
    e->kind = kind; e->inChannel = ch; e->inNote = inNote; e->outNote = outNote; e->velocity = vel;
    atomic_store_explicit(&k->ringHead, h + 1, memory_order_release);
}

int db_kernel_read_events(DBKernel *k, DBEvent *out, int max) {
    uint32_t tl = atomic_load_explicit(&k->ringTail, memory_order_relaxed);
    uint32_t h = atomic_load_explicit(&k->ringHead, memory_order_acquire);
    int n = 0;
    while (tl != h && n < max) { out[n++] = k->ring[tl & (RING - 1)]; tl++; }
    atomic_store_explicit(&k->ringTail, tl, memory_order_release);
    return n;
}

static inline uint8_t resolve_note(const DBTables *t, DBKernel *k, uint8_t ch, uint8_t note) {
    uint8_t r = t->route[ch][note];
    if (r == DB_ROUTE_PASS) return note;
    if (r == DB_ROUTE_HIHAT) {
        uint8_t g = t->hhGroup[ch][note] % DB_HH_GROUPS;
        uint8_t p = k->pedal[ch];
        int z = (t->hhCC == DB_NO_CC) ? 0 : (p >= t->hhClosedAt ? 0 : (p >= t->hhHalfAt ? 1 : 2));
        return t->hhOut[g][z];
    }
    return r; // note number or DB_ROUTE_DROP
}

int db_kernel_process(DBKernel *k, const uint8_t *in, int len, uint8_t *out) {
    const DBTables *t = tables_for_render(k);
    if (len <= 0) return 0;
    uint8_t status = in[0];
    if (status < 0x80) return 0;              // stray data byte
    if (status >= 0xF0 || len < 2) {          // system messages: pass as-is (max 3 bytes here)
        int n = len > 3 ? 3 : len;
        if (status == 0xF0) return 0;         // SysEx is not handled by this path
        memcpy(out, in, (size_t)n);
        return n;
    }
    uint8_t type = status & 0xF0, ch = status & 0x0F;
    uint8_t oc = (t->outChannel == DB_KEEP_CHANNEL) ? ch : (t->outChannel & 0x0F);
    int translate = (t->inChannel == DB_ANY_CHANNEL) || (t->inChannel == ch);
    uint8_t d1 = in[1] & 0x7F, d2 = len > 2 ? (in[2] & 0x7F) : 0;

    if (!translate) { memcpy(out, in, (size_t)(len > 3 ? 3 : len)); return len > 3 ? 3 : len; }

    if (type == 0x90 && d2 > 0) {             // note on
        uint8_t o = resolve_note(t, k, ch, d1);
        if (o == DB_ROUTE_DROP) { log_event(k, 0, ch, d1, DB_ROUTE_DROP, d2); return 0; }
        uint8_t v = t->velLUT[d2];
        if (v == 0) v = 1;
        k->sounding[ch][d1] = (uint8_t)(o + 1);
        k->soundCh[ch][d1] = oc;
        out[0] = 0x90 | oc; out[1] = o; out[2] = v;
        log_event(k, 0, ch, d1, o, v);
        return 3;
    }
    if (type == 0x80 || (type == 0x90 && d2 == 0)) {   // note off: release what we actually played
        uint8_t s = k->sounding[ch][d1];
        if (!s) return 0;
        k->sounding[ch][d1] = 0;
        out[0] = 0x80 | k->soundCh[ch][d1]; out[1] = (uint8_t)(s - 1); out[2] = (type == 0x80) ? d2 : 64;
        log_event(k, 1, ch, d1, (uint8_t)(s - 1), 0);
        return 3;
    }
    if (type == 0xA0) {                       // poly aftertouch (cymbal grabs) follows the note
        uint8_t s = k->sounding[ch][d1];
        uint8_t o = s ? (uint8_t)(s - 1) : resolve_note(t, k, ch, d1);
        if (o == DB_ROUTE_DROP) return 0;
        out[0] = 0xA0 | (s ? k->soundCh[ch][d1] : oc); out[1] = o; out[2] = d2;
        return 3;
    }
    if (type == 0xB0 && t->hhCC != DB_NO_CC && d1 == t->hhCC) {   // hi-hat pedal
        k->pedal[ch] = d2;
        if (t->pedalOutCC == DB_NO_CC) return 0;
        out[0] = 0xB0 | oc; out[1] = t->pedalOutCC; out[2] = d2;
        return 3;
    }
    // everything else: pass with the output channel applied
    int n = len > 3 ? 3 : len;
    memcpy(out, in, (size_t)n);
    out[0] = type | oc;
    return n;
}

int db_kernel_all_notes_off(DBKernel *k, uint8_t *out, int maxMsgs) {
    int n = 0;
    for (int c = 0; c < 16; c++)
        for (int i = 0; i < 128; i++) {
            if (!k->sounding[c][i]) continue;
            if (n >= maxMsgs) return n;
            out[n * 3] = 0x80 | k->soundCh[c][i];
            out[n * 3 + 1] = (uint8_t)(k->sounding[c][i] - 1);
            out[n * 3 + 2] = 0;
            k->sounding[c][i] = 0;
            n++;
        }
    return n;
}

void db_kernel_audition(DBKernel *k, uint8_t note, uint8_t velocity, int noteOn) {
    int cur = atomic_load_explicit(&k->active, memory_order_acquire);
    uint8_t oc = k->tables[cur].outChannel;
    if (oc == DB_KEEP_CHANNEL) oc = 9;
    uint32_t h = atomic_load_explicit(&k->aqHead, memory_order_relaxed);
    uint32_t tl = atomic_load_explicit(&k->aqTail, memory_order_acquire);
    if (h - tl >= AQ) return;
    uint8_t *m = k->aq[h & (AQ - 1)];
    m[0] = (noteOn ? 0x90 : 0x80) | (oc & 0x0F);
    m[1] = note & 0x7F;
    m[2] = noteOn ? (velocity ? (velocity & 0x7F) : 100) : 0;
    atomic_store_explicit(&k->aqHead, h + 1, memory_order_release);
}

int db_kernel_pop_audition(DBKernel *k, uint8_t *out) {
    (void)tables_for_render(k);  // also acknowledges the current table slot once per render block
    uint32_t tl = atomic_load_explicit(&k->aqTail, memory_order_relaxed);
    uint32_t h = atomic_load_explicit(&k->aqHead, memory_order_acquire);
    if (tl == h) return 0;
    memcpy(out, k->aq[tl & (AQ - 1)], 3);
    atomic_store_explicit(&k->aqTail, tl + 1, memory_order_release);
    if ((out[0] & 0xF0) == 0x90) log_event(k, 2, out[0] & 0x0F, out[1], out[1], out[2]);
    return 3;
}
