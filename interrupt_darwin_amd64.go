// Copyright 2018 The ctxfs Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package ctxfs

import (
	"unsafe"
)

type sigactiont struct {
	__sigaction_u [8]byte
	sa_tramp      unsafe.Pointer
	sa_mask       uint32
	sa_flags      int32
}
