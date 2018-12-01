// Copyright 2018 The ctxfs Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package ctxfs provides Context-aware file system access.
//
// A file is typically opened with Open or Create. The File object can
// provide io.Reader and io.Writer views on the file bound to a context
// using the IO method. For example to read a file:
//
//	ctx := context.WithTimeout(context.Background(), 1*time.Second)
//	f, err := fs.Open("file.go")
//	if err != nil {
//		log.Fatal(err)
//	}
//	b, err := ioutil.ReadAll(f.IO(ctx))
//	if err != nil {
//		log.Fatal(err)
//	}
//
// Interrupting the underlying system calls is implemented using operating
// system signals. This package uses SIGUSR1, programs that use this package
// should avoid using that signal to minimize the performance penalty.
//
// There are several known conditions where blocking system calls cannot be
// interrupted even by non-restartable signals. In those cases, canceling a
// context will not work. Examples include:
//
// - darwin will not interrupt a partially successful write to a pipe
//
// - linux will not interrupt normal disk I/O (see SA_RESTART in signal(7)).
//
// As cancellation of contexts should be treated as advisory, it is best to
// program with the expectation that some calls will not be cleaned up
// promptly. If this is not possible, calling the SetNonBlocking method on
// a File object will enable non-blocking I/O. The contract of the io.Reader
// and io.Writer interfaces will be met, though at a potential performance
// penalty.
//
// TODO: document and implement OpenLimit.
package ctxfs
