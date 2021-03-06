// Copyright 2018 The ctxfs Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "textflag.h"

// threadID is implemented in assembly rather than using the syscall
// package because mach_thread_self is a gnarly mach syscall, not a
// "normal" XNU kernel syscall. Who has two kernels, honestly?
TEXT ·threadID(SB),NOSPLIT,$0
        MOVL    $(0x1000000+27), AX // mach_thread_self
        SYSCALL
        MOVL    AX, ret+0(FP)
        RET

