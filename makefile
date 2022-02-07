.PHONY: all test clean style

DC ?= dmd
GIT ?= git
DMD := $(DC)
GDC := gdc
LDC := ldc2
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

UT_OBJ_DIR = unittest-obj
OBJ_DIR := obj
OBJ = $(SRC:.d=.o)
PROJECT_OBJ = $(PROJECT_SRC:.d=.o)
LIB_OBJ = $(LIB_SRC:.d=.o)

INCLUDE_PATHS = \
	-Isrc \
	-Iinifiled/source \
	-Ilibdparse/src \
	-Idsymbol/src \
	-Icontainers/src \
	-Ilibddoc/src \
	-Ilibddoc/common/source \
	-Istdx-allocator/source \
	-Idmd/src
VERSIONS = -version=CallbackAPI -version=DMDLIB
DEBUG_VERSIONS = -version=dparse_verbose
DMD_FLAGS = -w -release -O -Jbin -Jdmd -od${OBJ_DIR} -version=StdLoggerDisableWarning
override DMD_FLAGS += $(DFLAGS)
override LDC_FLAGS += $(DFLAGS)
override GDC_FLAGS += $(DFLAGS)
DMD_TEST_FLAGS = -w -g -Jbin -Jdmd -version=StdLoggerDisableWarning
override LDC_FLAGS += -O5 -release -oq -d-version=StdLoggerDisableWarning -Jbin
override GDC_FLAGS += -O3 -frelease -d-version=StdLoggerDisableWarning -Jbin
SHELL:=/usr/bin/env bash

DMD_EXE = bin/dmd/dscanner
LDC_EXE = bin/ldc/dscanner
GDC_EXE = bin/gdc/dscanner

GITHASH = bin/githash.txt

OBJ_BY_DMD = $(addprefix $(OBJ_DIR)/dmd/, $(OBJ))
UT_OBJ_BY_DMD = $(addprefix $(UT_OBJ_DIR)/dmd/, $(PROJECT_OBJ))

OBJ_BY_LDC = $(addprefix $(OBJ_DIR)/ldc/, $(OBJ))
UT_OBJ_BY_LDC = $(addprefix $(UT_OBJ_DIR)/ldc/, $(PROJECT_OBJ))

OBJ_BY_GDC = $(addprefix $(OBJ_DIR)/gdc/, $(OBJ))
UT_OBJ_BY_GDC = $(addprefix $(UT_OBJ_DIR)/gdc/, $(PROJECT_OBJ))

$(OBJ_DIR)/dmd/%.o: %.d
	@test -d $(dir $@) || mkdir -p $(dir $@)
	${DC} ${DMD_FLAGS} ${VERSIONS} ${INCLUDE_PATHS} -c $< -of=$@

$(UT_OBJ_DIR)/dmd/%.o: %.d
	@test -d $(dir $@) || mkdir -p $(dir $@)
	${DC} ${DMD_TEST_FLAGS} ${VERSIONS} -unittest ${INCLUDE_PATHS} -c $< -of=$@

$(OBJ_DIR)/ldc/%.o: %.d
	@test -d $(dir $@) || mkdir -p $(dir $@)
	${DC} ${LDC_FLAGS} ${VERSIONS} ${INCLUDE_PATHS} -c $< -of=$@

$(UT_OBJ_DIR)/ldc/%.o: %.d
	@test -d $(dir $@) || mkdir -p $(dir $@)
	${DC} ${LDC_TEST_FLAGS} ${VERSIONS} -unittest ${INCLUDE_PATHS} -c $< -of=$@

$(OBJ_DIR)/gdc/%.o: %.d
	@test -d $(dir $@) || mkdir -p $(dir $@)
	${DC} ${GDC_FLAGS} ${VERSIONS} ${INCLUDE_PATHS} -c $< -o $@

$(UT_OBJ_DIR)/gdc/%.o: %.d
	@test -d $(dir $@) || mkdir -p $(dir $@)
	${DC} ${GDC_TEST_FLAGS} ${VERSIONS} -unittest ${INCLUDE_PATHS} -c $< -o $@

all: ${DMD_EXE}
ldc: ${LDC_EXE}
gdc: ${GDC_EXE}

${GITHASH}:
	mkdir -p bin && ${GIT} describe --tags --always > ${GITHASH}

debug: ${GITHASH}
	${DC} -w -g -Jbin -ofdsc ${VERSIONS} ${DEBUG_VERSIONS} ${INCLUDE_PATHS} ${SRC}

${DMD_EXE}: ${GITHASH} ${OBJ_BY_DMD}
	${DC} -of${DMD_EXE} ${OBJ_BY_DMD}

${GDC_EXE}: ${GITHASH} ${OBJ_BY_GDC}
	${GDC} -o${GDC_EXE} ${OBJ_BY_GDC}

${LDC_EXE}: ${GITHASH} ${OBJ_BY_LDC}
	${LDC} -of=${DMD_EXE} ${OBJ_BY_LDC}

# compile the dependencies separately, s.t. their unittests don't get executed
bin/dmd/dscanner-unittest-lib.a: ${LIB_SRC}
	${DC} ${DMD_TEST_FLAGS} -c ${VERSIONS} ${INCLUDE_PATHS} ${LIB_SRC} -of$@

test: bin/dmd/dscanner-unittest-lib.a ${GITHASH} ${UT_OBJ_BY_DMD}
	${DC} bin/dmd/dscanner-unittest-lib.a ${UT_OBJ_BY_DMD} -ofbin/dmd/dscanner-unittest
	./bin/dmd/dscanner-unittest

lint: ${DMD_EXE}
	./${DMD_EXE} --config .dscanner.ini --styleCheck src

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

# Add source files here as we transition to DMD-as-a-library
STYLE_CHECKED_SRC := \
	src/dscanner/imports.d \
	src/dscanner/main.d

style:
	@echo "Check for trailing whitespace"
	grep -nr '[[:blank:]]$$' ${STYLE_CHECKED_SRC}; test $$? -eq 1

	@echo "Enforce whitespace before opening parenthesis"
	grep -nrE "\<(for|foreach|foreach_reverse|if|while|switch|catch|version)\(" ${STYLE_CHECKED_SRC} ; test $$? -eq 1

	@echo "Enforce no whitespace after opening parenthesis"
	grep -nrE "\<(version) \( " ${STYLE_CHECKED_SRC} ; test $$? -eq 1

	@echo "Enforce whitespace between colon(:) for import statements (doesn't catch everything)"
	grep -nr 'import [^/,=]*:.*;' ${STYLE_CHECKED_SRC} | grep -vE "import ([^ ]+) :\s"; test $$? -eq 1

	@echo "Check for package wide std.algorithm imports"
	grep -nr 'import std.algorithm : ' ${STYLE_CHECKED_SRC} ; test $$? -eq 1

	@echo "Enforce Allman style"
	grep -nrE '(if|for|foreach|foreach_reverse|while|unittest|switch|else|version) .*{$$' ${STYLE_CHECKED_SRC}; test $$? -eq 1

	@echo "Enforce do { to be in Allman style"
	grep -nr 'do *{$$' ${STYLE_CHECKED_SRC} ; test $$? -eq 1

	@echo "Enforce no space between assert and the opening brace, i.e. assert("
	grep -nrE 'assert +\(' ${STYLE_CHECKED_SRC} ; test $$? -eq 1

	@echo "Enforce space after cast(...)"
	grep -nrE '[^"]cast\([^)]*?\)[[:alnum:]]' ${STYLE_CHECKED_SRC} ; test $$? -eq 1

	@echo "Enforce space between a .. b"
	grep -nrE '[[:alnum:]][.][.][[:alnum:]]|[[:alnum:]] [.][.][[:alnum:]]|[[:alnum:]][.][.] [[:alnum:]]' ${STYLE_CHECKED_SRC}; test $$? -eq 1

	@echo "Enforce space between binary operators"
	grep -nrE "[[:alnum:]](==|!=|<=|<<|>>|>>>|^^)[[:alnum:]]|[[:alnum:]] (==|!=|<=|<<|>>|>>>|^^)[[:alnum:]]|[[:alnum:]](==|!=|<=|<<|>>|>>>|^^) [[:alnum:]]" ${STYLE_CHECKED_SRC}; test $$? -eq 1
