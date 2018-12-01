// Copyright 2018 The ctxfs Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package ctxfs

import (
	"context"
	"runtime"
	"syscall"
	"unsafe"
)

const intrSig = syscall.SIGUSR1

func funcPC(f interface{}) uintptr {
	const ptrSize = unsafe.Sizeof(uintptr(0))
	pc := uintptr(unsafe.Pointer(&f)) + ptrSize
	return **(**uintptr)(unsafe.Pointer(pc))
}

func sigtramp()

var intrHandler = func(sig int32) {}

func init() {
	setsighandler()
}

// interrupt starts a background task to send the current goroutine a SIGUSR1
// when ctx is done.
func interrupt(ctx context.Context) (cleanup func()) {
	runtime.LockOSThread()
	done := make(chan struct{}, 1)
	tid := threadID()

	//unblocksig()

	go func() {
		select {
		case <-ctx.Done():
			threadKill(tid)
		case <-done:
		}
	}()

	return func() {
		//blocksig()
		runtime.UnlockOSThread()
		done <- struct{}{} // don't leak goroutine
	}
}
