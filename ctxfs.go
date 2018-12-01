// Copyright 2018 The ctxfs Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package ctxfs

import (
	"context"
	"io"
	"os"
	"runtime"
	"syscall"
)

// OpenLimit is the maximum number of file descriptors that can be open
// simultaneously by the fs package.
//
// Initial value is 10% less than RLIMIT_NOFILE at process initialization.
var OpenLimit int

// IO is the interface provided to read and write files.
type IO interface {
	io.ReadWriteSeeker
	io.ReaderAt
	io.Closer
}

// File holds an open file descriptor.
type File struct {
	f *os.File
}

// IO returns an IO object bound to ctx for all of its operations.
//
// The underlying file descriptor is shared with File. IO can be called
// multiple times with different ctx values.
func (f *File) IO(ctx context.Context) IO {
	return fio{f.f, ctx}
}

// Name returns the name of the file as presented to Open.
func (f *File) Name() string {
	return f.f.Name()
}

// SetNonBlocking puts the underlying file descriptor into non-blocking mode.
// This is equivalent to O_NONBLOCK.
func (f *File) SetNonBlocking() {
	setnonblock(f.f.Fd())
}

func newFile(osf *os.File) *File {
	if osf == nil {
		return nil
	}
	f := &File{osf}
	runtime.SetFinalizer(osf, func(osf *os.File) {
		osf.Close()
		// TODO recover OpenLimit
	})
	return f
}

// Open opens the named file for reading.
//
// If the number of opened files exceeds OpenLimit, Open will block until
// another file is closed.
//
// If there is an error, it will be of type *PathError.
func Open(ctx context.Context, name string) (file *File, err error) {
	return OpenFile(ctx, name, os.O_RDONLY, 0)
}

// OpenFile is the generalized open call; most users will use Open
// or Create instead.
//
// If the number of open files exceeds OpenLimit, Open will block until
// another file is closed.
//
// If there is an error, it will be of type *os.PathError.
func OpenFile(ctx context.Context, name string, flag int, perm os.FileMode) (file *File, err error) {
	defer interrupt(ctx)()
	f, err := os.OpenFile(name, flag, perm)
	if err != nil {
		return nil, err
	}
	return newFile(f), nil
}

// Pipe returns a connected pair of Files; reads from r return bytes written to w.
func Pipe(ctx context.Context) (r, w *File, err error) {
	osr, osw, err := os.Pipe()
	if err != nil {
		return nil, nil, err
	}
	return newFile(osr), newFile(osw), nil
}

type fio struct {
	f   *os.File
	ctx context.Context
}

func (fio fio) Seek(offset int64, whence int) (int64, error) {
	defer interrupt(fio.ctx)()
	return fio.f.Seek(offset, whence)
}

// errAgain checks for EAGAIN or EINTR.
func errAgain(ctx context.Context, err error) error {
	if err == nil {
		return nil
	}
	perr, ok := err.(*os.PathError)
	if !ok {
		return err
	}
	switch perr.Err {
	case syscall.EAGAIN:
		return nil
	case syscall.EINTR:
		// Double check that the context is canceled.
		// If not, this may be a spurious signal
		// sent to the program for some other purpose.
		select {
		case <-ctx.Done():
			perr.Err = context.Canceled
			return perr
		default:
			return nil // keep going
		}
	default:
		return err
	}
}

func (fio fio) Write(p []byte) (int, error) {
	defer interrupt(fio.ctx)()
	n := 0
	for len(p) > 0 {
		wn, err := fio.f.Write(p)
		n += wn
		p = p[wn:]
		err = errAgain(fio.ctx, err)
		if err != nil {
			return n, err
		}
		select {
		case <-fio.ctx.Done():
			return n, &os.PathError{
				Op:   "write",
				Path: fio.f.Name(),
				Err:  context.Canceled,
			}
		default:
		}
	}
	return n, nil
}

func (fio fio) Read(data []byte) (int, error) {
	defer interrupt(fio.ctx)()

	// The io.Reader contract encourages us not to return zero bytes,
	// so we spin on EAGAIN until we are canceled or bytes appear.
	for {
		n, err := fio.f.Read(data)
		err = errAgain(fio.ctx, err)
		if err != nil {
			return n, err
		}
		if n > 0 {
			return n, err
		}
		select {
		case <-fio.ctx.Done():
			return n, &os.PathError{
				Op:   "write",
				Path: fio.f.Name(),
				Err:  context.Canceled,
			}
		default:
		}
	}
	return len(data), nil
}

func (fio fio) ReadAt(p []byte, off int64) (n int, err error) {
	defer interrupt(fio.ctx)()
	// TODO: oh dear O_NONBLOCK woes.
	return fio.f.ReadAt(p, off)
}

func (fio fio) Close() error {
	defer interrupt(fio.ctx)()
	return fio.f.Close()
	// TODO recover OpenLimit
}
