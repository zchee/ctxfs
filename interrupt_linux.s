// Copyright 2018 The ctxfs Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "textflag.h"

// sigreturn is borrowed from the runtime.
TEXT ·sigreturn(SB),NOSPLIT,$0
	JMP runtime·sigreturn(SB)
