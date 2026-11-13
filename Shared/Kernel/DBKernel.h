// DrumBridge kernel: real-time-safe MIDI drum map translation.
// Everything called from the render thread is lock-free and allocation-free.
#ifndef DBKERNEL_H
#define DBKERNEL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Values for DBTables.route
#define DB_ROUTE_DROP   255  // swallow the note
#define DB_ROUTE_PASS   254  // send the note unchanged
#define DB_ROUTE_HIHAT  253  // pedal-controlled hi-hat: hhGroup picks closed/half/open
// 0..127 = send this note number

#define DB_HH_GROUPS 4
#define DB_KEEP_CHANNEL 255
#define DB_ANY_CHANNEL 255
#define DB_NO_CC 255

typedef struct {
    uint8_t route[16][128];          // per input channel + note
    uint8_t hhGroup[16][128];        // used when route == DB_ROUTE_HIHAT
    uint8_t hhOut[DB_HH_GROUPS][3];  // [group][0=closed,1=half,2=open] -> note (DB_ROUTE_DROP = drop)
    uint8_t hhCC;                    // pedal controller from the device (DB_NO_CC = none)
    uint8_t hhClosedAt;              // pedal value >= this -> closed
    uint8_t hhHalfAt;                // pedal value >= this -> half open, below -> open
    uint8_t pedalOutCC;              // re-send the pedal as this CC (DB_NO_CC = swallow it)
    uint8_t velLUT[128];             // input velocity -> output velocity (1..127 for index >= 1)
    uint8_t outChannel;              // 0..15, or DB_KEEP_CHANNEL
    uint8_t inChannel;               // 0..15 only translate this channel, or DB_ANY_CHANNEL
} DBTables;

typedef struct {
    uint8_t kind;      // 0 = note on, 1 = note off, 2 = audition
    uint8_t inChannel; // 0..15
    uint8_t inNote;
    uint8_t outNote;   // DB_ROUTE_DROP when dropped
    uint8_t velocity;  // output velocity
} DBEvent;

typedef struct DBKernel DBKernel;

DBKernel *db_kernel_create(void);
void db_kernel_destroy(DBKernel *k);

// Fills t with an identity map (everything passes, linear velocity).
void db_tables_init(DBTables *t);
// Builds the velocity LUT. curve in [-1, 1] (0 = linear, >0 = louder), minVel 1..127.
void db_tables_set_velocity(DBTables *t, double curve, int minVel);

// Helpers (C arrays import awkwardly into Swift).
void db_tables_set_route(DBTables *t, int channel, int note, uint8_t route, uint8_t hhGroup);
void db_tables_set_hihat(DBTables *t, int group, int zone, uint8_t note);
uint8_t db_tables_get_route(const DBTables *t, int channel, int note);

// UI thread: publish new tables. Safe while render runs.
void db_kernel_set_tables(DBKernel *k, const DBTables *t);

// Render thread: translate one complete MIDI 1.0 message.
// Writes up to 3 bytes into out and returns the length (0 = dropped).
int db_kernel_process(DBKernel *k, const uint8_t *in, int len, uint8_t *out);

// Render thread: releases every sounding note. Fills out with up to maxMsgs 3-byte note-offs, returns count.
int db_kernel_all_notes_off(DBKernel *k, uint8_t *out, int maxMsgs);

// UI thread -> render: queue an audition note (sent on the output channel, or channel 10 when keeping channels).
void db_kernel_audition(DBKernel *k, uint8_t note, uint8_t velocity, int noteOn);
// Render thread: pop one queued audition message into out (3 bytes). Returns 3, or 0 when empty.
int db_kernel_pop_audition(DBKernel *k, uint8_t *out);

// UI thread: read activity events logged by the render thread. Returns how many were copied.
int db_kernel_read_events(DBKernel *k, DBEvent *out, int max);

#ifdef __cplusplus
}
#endif
#endif
