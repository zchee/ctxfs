// Copyright 2018 The ctxfs Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "textflag.h"

// sigtramp is borrowed from the runtime.
TEXT ·sigtramp(SB),NOSPLIT,$0
	JMP runtime·sigtramp(SB)
