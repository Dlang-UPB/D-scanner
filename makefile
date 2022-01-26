.PHONY: all test

DC ?= dmd
GIT ?= git
DMD := $(DC)
GDC := gdc
LDC := ldc2
OBJ_DIR := obj
DMD_ROOT_SRC := \
	$(shell find dmd/src/dmd/common -name "*.d")\
	$(shell find dmd/src/dmd/root -name "*.d")
DMD_LEXER_SRC := \
	dmd/src/dmd/console.d \
	dmd/src/dmd/entity.d \
	dmd/src/dmd/errors.d \
	dmd/src/dmd/file_manager.d \
	dmd/src/dmd/globals.d \
	dmd/src/dmd/id.d \
	dmd/src/dmd/identifier.d \
	dmd/src/dmd/lexer.d \
	dmd/src/dmd/tokens.d \
	dmd/src/dmd/utils.d \
	$(DMD_ROOT_SRC)

DMD_PARSER_SRC := \
	dmd/src/dmd/astbase.d \
	dmd/src/dmd/parse.d \
	dmd/src/dmd/parsetimevisitor.d \
	dmd/src/dmd/transitivevisitor.d \
	dmd/src/dmd/permissivevisitor.d \
	dmd/src/dmd/strictvisitor.d \
	dmd/src/dmd/astenums.d \
	$(DMD_LEXER_SRC)

LIB_SRC := \
	$(shell find containers/src -name "*.d")\
	$(shell find dsymbol/src -name "*.d")\
	$(shell find inifiled/source/ -name "*.d")\
	$(shell find libdparse/src/std/experimental/ -name "*.d")\
	$(shell find libdparse/src/dparse/ -name "*.d")\
	$(shell find libddoc/src -name "*.d") \
	$(shell find libddoc/common/source -name "*.d") \
	$(shell find stdx-allocator/source -name "*.d") \
	$(DMD_PARSER_SRC)
PROJECT_SRC := $(shell find src/ -name "*.d")
SRC := $(LIB_SRC) $(PROJECT_SRC)
INCLUDE_PATHS = \
	-Isrc \
	-Iinifiled/source \
	-Ilibdparse/src \
	-Idsymbol/src \
	-Icontainers/src \
	-Ilibddoc/src \
	-Ilibddoc/common/source \
	-Istdx-allocator/source
VERSIONS = -version=CallbackAPI -version=DMDLIB
DEBUG_VERSIONS = -version=dparse_verbose
DMD_FLAGS = -w -release -O -Jbin -Jdmd -od${OBJ_DIR} -version=StdLoggerDisableWarning
override DMD_FLAGS += $(DFLAGS)
override LDC_FLAGS += $(DFLAGS)
override GDC_FLAGS += $(DFLAGS)
DMD_TEST_FLAGS = -w -g -Jbin -Jdmd -version=StdLoggerDisableWarning
override LDC_FLAGS += -O5 -release -oq -d-version=StdLoggerDisableWarning
override GDC_FLAGS += -O3 -frelease -d-version=StdLoggerDisableWarning
SHELL:=/usr/bin/env bash

all: dmdbuild
ldc: ldcbuild
gdc: gdcbuild

githash:
	mkdir -p bin && ${GIT} describe --tags --always > bin/githash.txt

debug: githash
	${DC} -w -g -Jbin -ofdsc ${VERSIONS} ${DEBUG_VERSIONS} ${INCLUDE_PATHS} ${SRC}

dmdbuild: githash
	${DC} ${DMD_FLAGS} -ofbin/dscanner ${VERSIONS} ${INCLUDE_PATHS} ${SRC}
	rm -f bin/dscanner.o

gdcbuild: githash
	${GDC} ${GDC_FLAGS} -obin/dscanner ${VERSIONS} ${INCLUDE_PATHS} ${SRC} -Jbin

ldcbuild: githash
	${LDC} ${LDC_FLAGS} -of=bin/dscanner ${VERSIONS} ${INCLUDE_PATHS} ${SRC} -Jbin

# compile the dependencies separately, s.t. their unittests don't get executed
bin/dscanner-unittest-lib.a: ${LIB_SRC}
	${DC} ${DMD_TEST_FLAGS} -c ${VERSIONS} ${INCLUDE_PATHS} ${LIB_SRC} -of$@

test: bin/dscanner-unittest-lib.a githash
	${DC} ${DMD_TEST_FLAGS} -unittest ${INCLUDE_PATHS} bin/dscanner-unittest-lib.a ${PROJECT_SRC} -ofbin/dscanner-unittest
	./bin/dscanner-unittest
	rm -f bin/dscanner-unittest

lint: dmdbuild
	./bin/dscanner --config .dscanner.ini --styleCheck src

clean:
	rm -rf dsc
	rm -rf bin
	rm -rf ${OBJ_DIR}
	rm -f dscanner-report.json

report: all
	dscanner --report src > src/dscanner-report.json
	sonar-runner

release:
	./release.sh
