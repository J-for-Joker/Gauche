/*
 * guess.c - guessing character encoding 
 *
 *   Copyright (c) 2000-2008  Shiro Kawai  <shiro@acm.org>
 * 
 *   Redistribution and use in source and binary forms, with or without
 *   modification, are permitted provided that the following conditions
 *   are met:
 * 
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *   3. Neither the name of the authors nor the names of its contributors
 *      may be used to endorse or promote products derived from this
 *      software without specific prior written permission.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 *   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *  $Id: guess.c,v 1.6 2008-05-10 13:35:37 shirok Exp $
 */

#include <gauche.h>
#include <gauche/extend.h>
#include "charconv.h"

typedef struct guess_arc_rec {
    unsigned int next;          /* next state */
    double score;               /* score */
} guess_arc;

typedef struct guess_dfa_rec {
    signed char (*states)[256];
    guess_arc *arcs;
    int state;
    double score;
} guess_dfa;

#define DFA_INIT(st, ar) \
    { st, ar, 0, 1.0 }

#define DFA_NEXT(dfa, ch)                               \
    do {                                                \
        int arc__;                                      \
        if (dfa.state >= 0) {                           \
            arc__ = dfa.states[dfa.state][ch];          \
            if (arc__ < 0) {                            \
                dfa.state = -1;                         \
            } else {                                    \
                dfa.state = dfa.arcs[arc__].next;       \
                dfa.score *= dfa.arcs[arc__].score;     \
            }                                           \
        }                                               \
    } while (0)

#define DFA_ALIVE(dfa)  (dfa.state >= 0)

/* include DFA table generated by guess.scm */
#include "guess_tab.c"

static const char *guess_jp(const char *buf, int buflen, void *data)
{
    int i;
    guess_dfa eucj = DFA_INIT(guess_eucj_st, guess_eucj_ar);
    guess_dfa sjis = DFA_INIT(guess_sjis_st, guess_sjis_ar);
    guess_dfa utf8 = DFA_INIT(guess_utf8_st, guess_utf8_ar);
    guess_dfa *top = NULL;

    for (i=0; i<buflen; i++) {
        int c = (unsigned char)buf[i];

        /* special treatment of jis escape sequence */
        if (c == 0x1b) {
            if (i < buflen-1) {
                c = (unsigned char)buf[++i];
                if (c == '$' || c == '(') return "ISO-2022-JP";
            }
        }
        
        if (DFA_ALIVE(eucj)) {
            if (!DFA_ALIVE(sjis) && !DFA_ALIVE(utf8)) return "EUC-JP";
            DFA_NEXT(eucj, c);
        }
        if (DFA_ALIVE(sjis)) {
            if (!DFA_ALIVE(eucj) && !DFA_ALIVE(utf8)) return "Shift_JIS";
            DFA_NEXT(sjis, c);
        }
        if (DFA_ALIVE(utf8)) {
            if (!DFA_ALIVE(sjis) && !DFA_ALIVE(eucj)) return "UTF-8";
            DFA_NEXT(utf8, c);
        }

        if (!DFA_ALIVE(eucj) && !DFA_ALIVE(sjis) && !DFA_ALIVE(utf8)) {
            /* we ran out the possibilities */
            return NULL;
        }
    }

    /* Now, we have ambigous code.  Pick the highest score.  If more than
       one candidate tie, pick the default encoding. */
    if (DFA_ALIVE(eucj)) top = &eucj;
    if (DFA_ALIVE(utf8)) {
        if (top) {
#if defined GAUCHE_CHAR_ENCODING_UTF_8
            if (top->score <= utf8.score)  top = &utf8;
#else
            if (top->score <  utf8.score) top = &utf8;
#endif
        } else {
            top = &utf8;
        }
    }
    if (DFA_ALIVE(sjis)) {
        if (top) {
#if defined GAUCHE_CHAR_ENCODING_SJIS
            if (top->score <= sjis.score)  top = &sjis;
#else
            if (top->score <  sjis.score) top = &sjis;
#endif
        } else {
            top = &sjis;
        }
    }

    if (top == &eucj) return "EUC-JP";
    if (top == &utf8) return "UTF-8";
    if (top == &sjis) return "Shift_JIS";
    return NULL;
}


/*
 * Initialization
 */

void Scm_Init_convguess(void)
{
    Scm_RegisterCodeGuessingProc("*JP", guess_jp, NULL);
}

