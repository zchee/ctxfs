// Copyright 2018 The ctxfs Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package ctxfs

type sigactiont struct {
	sa_handler  uintptr
	sa_flags    uint32
	sa_restorer uintptr
	sa_mask     uint64
}
