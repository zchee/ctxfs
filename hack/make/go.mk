# ----------------------------------------------------------------------------
# global

SHELL = /usr/bin/env bash
 
GO_PATH = $(shell go env GOPATH)
PKG = $(subst $(GO_PATH)/src/,,$(CURDIR))
GO_PKGS := $(shell go list ./... | grep -v -e '.pb.go')
GO_PKGS_ABS := $(shell go list -f '$(GO_PATH)/src/{{.ImportPath}}' ./... | grep -v -e '.pb.go')
GO_TEST_PKGS := $(shell go list -f='{{if or .TestGoFiles .XTestGoFiles}}{{.ImportPath}}{{end}}' ./...)

CGO_ENABLED := 1
GO_LDFLAGS=-ldflags "-w $(CTIMEVAR)"
GO_LDFLAGS_STATIC=-ldflags "-w $(CTIMEVAR) -extldflags -static"
GO_BUILDTAGS := osusergo

GO_TEST ?= go test
GO_TEST_FUNC ?= .
GO_TEST_FLAGS ?=
GO_BENCH_FUNC ?= .
GO_BENCH_FLAGS ?= -benchmem

VET_LINTERS := asmdecl assign atomic bools buildtag cgocall copylocks httpresponse loopclosure lostcancel nilfunc nilness pkgfact shift stdmethods structtag tests unreachable unsafeptr  # composites -composites.whitelist '' findcall -findcall.name '' printf -printf.funcs '' unusedresult -unusedresult.funcs '' -unusedresult.stringmethods ''
GOLANGCI_LINTERS := deadcode dupl errcheck goconst gocyclo golint gosec ineffassign interfacer maligned megacheck structcheck unconvert varcheck 
GOLANGCI_EXCLUDE :=
ifneq ($(wildcard '.errcheckignore'),)
	GOLANGCI_EXCLUDE = $(foreach pat,$(shell cat .errcheckignore),--exclude '$(pat)')
endif

# ----------------------------------------------------------------------------
# defines

define target
@printf "+ \\033[32m$(patsubst ,$@,$(1))\\033[0m\\n"
endef

# ----------------------------------------------------------------------------
# targets

## test, bench and coverage

.PHONY: test
test:  ## Run the package test with checks race condition.
	$(call target)
	$(GO_TEST) -v -race -tags "$(GO_BUILDTAGS)" -run=$(GO_TEST_FUNC) $(GO_TEST_FLAGS) $(GO_TEST_PKGS)

.PHONY: test/cpu
test/cpu: GO_TEST_FLAGS+=-cpuprofile cpu.out
test/cpu: test  ## Run the package test with take a cpu profiling.
	$(call target)

.PHONY: test/mem
test/mem: GO_TEST_FLAGS+=-memprofile mem.out
test/mem: test  ## Run the package test with take a memory profiling.
	$(call target)

.PHONY: test/mutex
test/mutex: GO_TEST_FLAGS+=-mutexprofile mutex.out
test/mutex: test  ## Run the package test with take a mutex profiling.
	$(call target)

.PHONY: test/block
test/block: GO_TEST_FLAGS+=-blockprofile block.out
test/block: test  ## Run the package test with take a blockingh profiling.
	$(call target)

.PHONY: test/trace
test/trace: GO_TEST_FLAGS+=-trace trace.out
test/trace: test  ## Run the package test with take a trace profiling.
	$(call target)

.PHONY: bench
bench:  ## Take a package benchmark.
	$(call target)
	$(GO_TEST) -v -tags "$(GO_BUILDTAGS)" -run='^$$' -bench=$(GO_BENCH_FUNC) $(GO_BENCH_FLAGS) $(GO_TEST_PKGS)

.PHONY: bench/race
bench/race:  ## Take a package benchmark with checks race condition.
	$(call target)
	$(GO_TEST) -v -race -tags "$(GO_BUILDTAGS)" -run='^$$' -bench=$(GO_BENCH_FUNC) $(GO_BENCH_FLAGS) $(GO_TEST_PKGS)

.PHONY: bench/cpu
bench/cpu: GO_BENCH_FLAGS+=-cpuprofile cpu.out
bench/cpu: bench  ## Take a package benchmark with take a cpu profiling.

.PHONY: bench/trace
bench/trace:  ## Take a package benchmark with take a trace profiling.
	$(GO_TEST) -v -c -o bench-trace.test $(PKG)/stackdriver
	GODEBUG=allocfreetrace=1 ./bench-trace.test -test.run=none -test.bench=$(GO_BENCH_FUNC) -test.benchmem -test.benchtime=10ms 2> trace.log

.PHONY: coverage
coverage:  ## Take test coverage.
	$(call target)
	$(GO_TEST) -v -tags "$(GO_BUILDTAGS)" -covermode=atomic -coverpkg=$(PKG)/... -coverprofile=coverage.out $(GO_TEST_PKGS)

$(GO_PATH)/bin/go-junit-report:
	@go get -u github.com/jstemmer/go-junit-report

cmd/go-junit-report: $(GO_PATH)/bin/go-junit-report  # go get 'go-junit-report' binary

.PHONY: coverage/junit
coverage/junit: cmd/go-junit-report  ## Take test coverage and output test results with junit syntax.
	$(call target)
	mkdir -p _test-results
	$(GO_TEST) -v -tags "$(GO_BUILDTAGS)" -covermode=atomic -coverpkg=$(PKG)/... -coverprofile=coverage.out $(GO_TEST_PKGS) 2>&1 | go-junit-report > _test-results/results.xml


## lint

lint: lint/fmt lint/govet lint/golint lint/vet lint/golangci-lint  ## Run all linters.

.PHONY: lint/fmt
lint/fmt:  ## Verifies all files have been `gofmt`ed.
	$(call target)
	@gofmt -s -l . | grep -v '.pb.go' | tee /dev/stderr

.PHONY: lint/govet
lint/govet:  ## Verifies `go vet` passes.
	$(call target)
	@go vet -all $(GO_PKGS) | tee /dev/stderr

$(GO_PATH)/bin/golint:
	@go get -u golang.org/x/lint/golint

cmd/golint: $(GO_PATH)/bin/golint  # go get 'golint' binary

.PHONY: lint/golint
lint/golint: cmd/golint  ## Verifies `golint` passes.
	$(call target)
	@golint -min_confidence=0.3 -set_exit_status $(GO_PKGS)

lint/vet:  ## Run vet
	$(call target)
	@vet $(foreach linter,$(VET_LINTERS),-$(linter).enable) $(GO_PKGS)

$(GO_PATH)/bin/golangci-lint:
	@go get -u github.com/golangci/golangci-lint/cmd/golangci-lint

cmd/golangci-lint: $(GO_PATH)/bin/golangci-lint  # go get 'golangci-lint' binary

.PHONY: golangci-lint
lint/golangci-lint: cmd/golangci-lint  ## Run golangci-lint.
	$(call target)
	@golangci-lint run --no-config --issues-exit-code=0 $(GOLANGCI_EXCLUDE) --deadline=30m --disable-all $(foreach tool,$(GOLANGCI_LINTERS),--enable=$(tool)) $(GO_PKGS_ABS)


## mod

go.mod:
	$(call target,mod/init)
	@GO111MODULE=on go mod init

mod/init: go.mod

go.sum: go.mod
	$(call target,mod/tidy)
	@GO111MODULE=on go mod tidy -v

mod/tidy: go.mod go.sum

mod/vendor: go.mod go.sum
	$(call target)
	@GO111MODULE=on go mod vendor -v

.PHONY: mod/clean
mod/clean:
	$(call target)
	@$(RM) go.mod go.sum
	@$(RM) -r vendor

mod: mod/clean mod/init mod/tidy mod/vendor  ## Updates the vendoring directory via go mod.


## dep

$(GO_PATH)/bin/dep:
	@go get -u github.com/golang/dep/cmd/dep

cmd/dep: $(GO_PATH)/bin/dep

.PHONY: dep/init
dep/init: cmd/dep  ## Fetch vendor packages via dep ensure.
	$(call target)
	@dep init -v -no-examples

.PHONY: dep/ensure
dep/ensure: cmd/dep Gopkg.toml  ## Fetch vendor packages via dep ensure.
	$(call target)
	@dep ensure -v

.PHONY: dep/ensure/only-vendor
dep/ensure/only-vendor: cmd/dep Gopkg.toml Gopkg.lock  ## Fetch vendor packages via dep ensure.
	$(call target)
	@dep ensure -v -vendor-only

.PHONY: dep/clean
dep/clean: cmd/dep
	$(call target)
	@$(RM) Gopkg.toml Gopkg.lock
	@$(RM) -r vendor

.PHONY: dep/update
dep/update: cmd/dep dep/clean
	$(call target)
	@dep ensure -v -update

.PHONY: dep/init
dep: dep/clean dep/update  ## Updates the vendoring directory via dep.


## miscellaneous

boilerplate/go/%: BOILERPLATE_PKG_NAME=$(if $(findstring $@,cmd),main,$(shell printf $@ | rev | cut -d/ -f2 | rev))
boilerplate/go/%: hack/boilerplate/boilerplate.go.txt  ## Create go file from boilerplate.go.txt
	@cat hack/boilerplate/boilerplate.go.txt <(printf "package ${BOILERPLATE_PKG_NAME}\\n") > $*


.PHONY: AUTHORS
AUTHORS:  ## Creates AUTHORS file.
	@$(file >$@,# This file lists all individuals having contributed content to the repository.)
	@$(file >>$@,# For how it is generated, see `make AUTHORS`.)
	@printf "$(shell git log --format="\n%aN <%aE>" | LC_ALL=C.UTF-8 sort -uf)" >> $@


.PHONY: clean
clean:  ## Cleanup any build binaries or packages.
	$(call target)
	$(RM) *.out *.test *.prof trace.log


.PHONY: help
help:  ## Show make target help.
	@perl -nle 'BEGIN {printf "Usage:\n  make \033[33m<target>\033[0m\n\nTargets:\n"} printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 if /^([a-zA-Z\/_-].+)+:.*?\s+## (.*)/' ${MAKEFILE_LIST}
