@echo off
setlocal enabledelayedexpansion

if "%DC%"=="" set DC="dmd"
if "%DC%"=="ldc2" set DC="ldmd2"
if "%MFLAGS%"=="" set MFLAGS="-m32"

:: git might not be installed, so we provide 0.0.0 as a fallback or use
:: the existing githash file if existent
if not exist "bin" mkdir bin
git describe --tags > bin\githash_.txt
for /f %%i in ("bin\githash_.txt") do set githashsize=%%~zi
if %githashsize% == 0 (
	if not exist "bin\githash.txt" (
		echo v0.0.0 > bin\githash.txt
	)
) else (
	move /y bin\githash_.txt bin\githash.txt
)

set DFLAGS=-O -release -version=StdLoggerDisableWarning -version=CallbackAPI -version=DMDLIB -version=MARS -Jbin -Jdmd -Jdmd\compiler\src\dmd\res %MFLAGS%
set TESTFLAGS=-g -w -version=StdLoggerDisableWarning -version=CallbackAPI -version=DMDLIB -version=MARS -Jbin -Jdmd -Jdmd\compiler\src\dmd\res
set CORE=
set LIBDPARSE=
set STD=
set ANALYSIS=
set INIFILED=
set DSYMBOL=
set CONTAINERS=
set LIBDDOC=

@REM set DMD_FRONTEND_SRC=
@REM for %%x in (dmd\compiler\src\dmd\common\*.d) do set DMD_FRONTEND_SRC=!DMD_FRONTEND_SRC! %%x
@REM for %%x in (dmd\compiler\src\dmd\root\*.d) do set DMD_FRONTEND_SRC=!DMD_FRONTEND_SRC! %%x
@REM for %%x in (dmd\compiler\src\dmd\backend\*.d) do set DMD_FRONTEND_SRC=!DMD_FRONTEND_SRC! %%x
@REM for %%x in (dmd\compiler\src\dmd\*.d) do set DMD_FRONTEND_SRC=!DMD_FRONTEND_SRC! %%x
@REM for %%x in (dmd\compiler\src\dmd\*.d) do (
@REM 	if not "%%~nx"=="mars" (
@REM         set DMD_FRONTEND_SRC=!DMD_FRONTEND_SRC! %%x
@REM     )
@REM )


set DMD_FRONTEND_SRC=dmd\compiler\src\dmd\common\outbuffer.d dmd\compiler\src\dmd\common\bitfields.d dmd\compiler\src\dmd\backend\os.d dmd\compiler\src\dmd\backend\code_x86.d dmd\compiler\src\dmd\backend\obj.d dmd\compiler\src\dmd\backend\gsroa.d dmd\compiler\src\dmd\backend\dt.d dmd\compiler\src\dmd\backend\el.d dmd\compiler\src\dmd\backend\dwarfdbginf.d dmd\compiler\src\dmd\backend\cdef.d dmd\compiler\src\dmd\backend\barray.d dmd\compiler\src\dmd\backend\backend.d dmd\compiler\src\dmd\backend\mscoffobj.d dmd\compiler\src\dmd\backend\cgcse.d dmd\compiler\src\dmd\backend\gloop.d dmd\compiler\src\dmd\backend\cgelem.d dmd\compiler\src\dmd\backend\newman.d dmd\compiler\src\dmd\backend\disasm86.d dmd\compiler\src\dmd\backend\cc.d dmd\compiler\src\dmd\backend\inliner.d dmd\compiler\src\dmd\backend\go.d dmd\compiler\src\dmd\backend\dvec.d dmd\compiler\src\dmd\backend\cgen.d dmd\compiler\src\dmd\backend\gdag.d dmd\compiler\src\dmd\backend\cg.d dmd\compiler\src\dmd\backend\cgcod.d dmd\compiler\src\dmd\backend\compress.d dmd\compiler\src\dmd\backend\symtab.d dmd\compiler\src\dmd\backend\dlist.d dmd\compiler\src\dmd\backend\filespec.d dmd\compiler\src\dmd\backend\ptrntab.d dmd\compiler\src\dmd\backend\var.d dmd\compiler\src\dmd\backend\iasm.d dmd\compiler\src\dmd\backend\glocal.d dmd\compiler\src\dmd\backend\code.d dmd\compiler\src\dmd\backend\cgsched.d dmd\compiler\src\dmd\backend\cod2.d dmd\compiler\src\dmd\backend\fp.d dmd\compiler\src\dmd\backend\ee.d dmd\compiler\src\dmd\backend\elfobj.d dmd\compiler\src\dmd\backend\dcode.d dmd\compiler\src\dmd\backend\pdata.d dmd\compiler\src\dmd\backend\mscoff.d dmd\compiler\src\dmd\backend\mach.d dmd\compiler\src\dmd\backend\mem.d dmd\compiler\src\dmd\backend\cgcv.d dmd\compiler\src\dmd\backend\dtype.d dmd\compiler\src\dmd\backend\cod4.d dmd\compiler\src\dmd\backend\backconfig.d dmd\compiler\src\dmd\backend\machobj.d dmd\compiler\src\dmd\backend\ph2.d dmd\compiler\src\dmd\backend\cv4.d dmd\compiler\src\dmd\backend\cgxmm.d dmd\compiler\src\dmd\backend\nteh.d
set DMD_FRONTEND_SRC2=dmd\compiler\src\dmd\backend\util2.d dmd\compiler\src\dmd\backend\gflow.d dmd\compiler\src\dmd\backend\melf.d dmd\compiler\src\dmd\backend\rtlsym.d dmd\compiler\src\dmd\backend\cgreg.d dmd\compiler\src\dmd\backend\cv8.d dmd\compiler\src\dmd\backend\elpicpie.d dmd\compiler\src\dmd\backend\aarray.d dmd\compiler\src\dmd\backend\cod5.d dmd\compiler\src\dmd\backend\cg87.d dmd\compiler\src\dmd\backend\gother.d dmd\compiler\src\dmd\backend\dcgcv.d dmd\compiler\src\dmd\backend\elem.d dmd\compiler\src\dmd\backend\type.d dmd\compiler\src\dmd\backend\md5.d dmd\compiler\src\dmd\backend\blockopt.d dmd\compiler\src\dmd\backend\out.d dmd\compiler\src\dmd\backend\xmm.d dmd\compiler\src\dmd\backend\global.d dmd\compiler\src\dmd\backend\dwarf.d dmd\compiler\src\dmd\backend\cod3.d dmd\compiler\src\dmd\backend\codebuilder.d dmd\compiler\src\dmd\mustuse.d dmd\compiler\src\dmd\scanelf.d dmd\compiler\src\dmd\dmangle.d dmd\compiler\src\dmd\tokens.d dmd\compiler\src\dmd\libelf.d dmd\compiler\src\dmd\attrib.d dmd\compiler\src\dmd\ob.d dmd\compiler\src\dmd\dtoh.d dmd\compiler\src\dmd\astenums.d dmd\compiler\src\dmd\libmscoff.d dmd\compiler\src\dmd\blockexit.d dmd\compiler\src\dmd\dstruct.d dmd\compiler\src\dmd\dmacro.d dmd\compiler\src\dmd\aliasthis.d dmd\compiler\src\dmd\cli.d dmd\compiler\src\dmd\impcnvtab.d dmd\compiler\src\dmd\compiler.d dmd\compiler\src\dmd\traits.d dmd\compiler\src\dmd\apply.d dmd\compiler\src\dmd\libomf.d dmd\compiler\src\dmd\inline.d dmd\compiler\src\dmd\importc.d dmd\compiler\src\dmd\cpreprocess.d dmd\compiler\src\dmd\dmodule.d dmd\compiler\src\dmd\dsymbol.d dmd\compiler\src\dmd\ast_node.d dmd\compiler\src\dmd\sideeffect.d dmd\compiler\src\dmd\declaration.d dmd\compiler\src\dmd\todt.d dmd\compiler\src\dmd\initsem.d dmd\compiler\src\dmd\objc.d dmd\compiler\src\dmd\ctfeexpr.d dmd\compiler\src\dmd\tocvdebug.d dmd\compiler\src\dmd\dscope.d dmd\compiler\src\dmd\typesem.d dmd\compiler\src\dmd\expressionsem.d dmd\compiler\src\dmd\clone.d dmd\compiler\src\dmd\libmach.d dmd\compiler\src\dmd\access.d
set DMD_FRONTEND_SRC3=dmd\compiler\src\dmd\statement.d dmd\compiler\src\dmd\lib.d dmd\compiler\src\dmd\cparse.d dmd\compiler\src\dmd\glue.d dmd\compiler\src\dmd\json.d dmd\compiler\src\dmd\dmsc.d dmd\compiler\src\dmd\iasm.d dmd\compiler\src\dmd\ctorflow.d dmd\compiler\src\dmd\e2ir.d dmd\compiler\src\dmd\foreachvar.d dmd\compiler\src\dmd\toobj.d dmd\compiler\src\dmd\link.d dmd\compiler\src\dmd\argtypes_sysv_x64.d dmd\compiler\src\dmd\parse.d dmd\compiler\src\dmd\nspace.d dmd\compiler\src\dmd\argtypes_aarch64.d dmd\compiler\src\dmd\semantic2.d dmd\compiler\src\dmd\dclass.d dmd\compiler\src\dmd\scanmach.d dmd\compiler\src\dmd\argtypes_x86.d dmd\compiler\src\dmd\delegatize.d dmd\compiler\src\dmd\intrange.d dmd\compiler\src\dmd\visitor.d dmd\compiler\src\dmd\dversion.d dmd\compiler\src\dmd\init.d dmd\compiler\src\dmd\errors.d dmd\compiler\src\dmd\globals.d dmd\compiler\src\dmd\denum.d dmd\compiler\src\dmd\dinifile.d dmd\compiler\src\dmd\imphint.d dmd\compiler\src\dmd\astcodegen.d dmd\compiler\src\dmd\dimport.d dmd\compiler\src\dmd\utils.d dmd\compiler\src\dmd\objc_glue.d dmd\compiler\src\dmd\entity.d dmd\compiler\src\dmd\dtemplate.d dmd\compiler\src\dmd\expression.d dmd\compiler\src\dmd\lexer.d dmd\compiler\src\dmd\nogc.d dmd\compiler\src\dmd\cppmangle.d dmd\compiler\src\dmd\file_manager.d dmd\compiler\src\dmd\templateparamsem.d dmd\compiler\src\dmd\safe.d dmd\compiler\src\dmd\arrayop.d dmd\compiler\src\dmd\staticcond.d dmd\compiler\src\dmd\constfold.d dmd\compiler\src\dmd\strictvisitor.d dmd\compiler\src\dmd\toir.d dmd\compiler\src\dmd\cppmanglewin.d dmd\compiler\src\dmd\stmtstate.d dmd\compiler\src\dmd\transitivevisitor.d dmd\compiler\src\dmd\printast.d dmd\compiler\src\dmd\optimize.d dmd\compiler\src\dmd\func.d dmd\compiler\src\dmd\lambdacomp.d dmd\compiler\src\dmd\parsetimevisitor.d dmd\compiler\src\dmd\eh.d dmd\compiler\src\dmd\opover.d dmd\compiler\src\dmd\permissivevisitor.d dmd\compiler\src\dmd\typinf.d dmd\compiler\src\dmd\dsymbolsem.d dmd\compiler\src\dmd\doc.d
set DMD_FRONTEND_SRC4=dmd\compiler\src\dmd\astbase.d dmd\compiler\src\dmd\iasmgcc.d dmd\compiler\src\dmd\gluelayer.d dmd\compiler\src\dmd\statement_rewrite_walker.d dmd\compiler\src\dmd\hdrgen.d dmd\compiler\src\dmd\scanomf.d dmd\compiler\src\dmd\toctype.d dmd\compiler\src\dmd\arraytypes.d dmd\compiler\src\dmd\escape.d dmd\compiler\src\dmd\dinterpret.d dmd\compiler\src\dmd\tocsym.d dmd\compiler\src\dmd\mtype.d dmd\compiler\src\dmd\cond.d dmd\compiler\src\dmd\dmdparams.d dmd\compiler\src\dmd\statementsem.d dmd\compiler\src\dmd\staticassert.d dmd\compiler\src\dmd\id.d dmd\compiler\src\dmd\asttypename.d dmd\compiler\src\dmd\builtin.d dmd\compiler\src\dmd\sapply.d dmd\compiler\src\dmd\frontend.d dmd\compiler\src\dmd\target.d dmd\compiler\src\dmd\chkformat.d dmd\compiler\src\dmd\dcast.d dmd\compiler\src\dmd\console.d dmd\compiler\src\dmd\iasmdmd.d dmd\compiler\src\dmd\aggregate.d dmd\compiler\src\dmd\errorsink.d dmd\compiler\src\dmd\identifier.d dmd\compiler\src\dmd\vsoptions.d dmd\compiler\src\dmd\scanmscoff.d dmd\compiler\src\dmd\canthrow.d dmd\compiler\src\dmd\semantic3.d dmd\compiler\src\dmd\location.d dmd\compiler\src\dmd\s2ir.d dmd\compiler\src\dmd\inlinecost.d 


set DMD_ROOT_SRC=
for %%x in (dmd\compiler\src\dmd\common\*.d) do set DMD_ROOT_SRC=!DMD_ROOT_SRC! %%x
for %%x in (dmd\compiler\src\dmd\root\*.d) do set DMD_ROOT_SRC=!DMD_ROOT_SRC! %%x

set DMD_LEXER_SRC=^
	dmd\compiler\src\dmd\console.d ^
	dmd\compiler\src\dmd\entity.d ^
	dmd\compiler\src\dmd\errors.d ^
	dmd\compiler\src\dmd\file_manager.d ^
	dmd\compiler\src\dmd\globals.d ^
	dmd\compiler\src\dmd\id.d ^
	dmd\compiler\src\dmd\identifier.d ^
	dmd\compiler\src\dmd\lexer.d ^
	dmd\compiler\src\dmd\tokens.d ^
	dmd\compiler\src\dmd\utils.d

set DMD_PARSER_SRC=^
	dmd\compiler\src\dmd\astbase.d ^
	dmd\compiler\src\dmd\parse.d ^
	dmd\compiler\src\dmd\parsetimevisitor.d ^
	dmd\compiler\src\dmd\transitivevisitor.d ^
	dmd\compiler\src\dmd\permissivevisitor.d ^
	dmd\compiler\src\dmd\strictvisitor.d ^
	dmd\compiler\src\dmd\astenums.d

for %%x in (src\dscanner\*.d) do set CORE=!CORE! %%x
for %%x in (src\dscanner\analysis\*.d) do set ANALYSIS=!ANALYSIS! %%x
for %%x in (libdparse\src\dparse\*.d) do set LIBDPARSE=!LIBDPARSE! %%x
for %%x in (libdparse\src\std\experimental\*.d) do set LIBDPARSE=!LIBDPARSE! %%x
for %%x in (libddoc\src\ddoc\*.d) do set LIBDDOC=!LIBDDOC! %%x
for %%x in (libddoc\common\source\ddoc\*.d) do set LIBDDOC=!LIBDDOC! %%x
for %%x in (inifiled\source\*.d) do set INIFILED=!INIFILED! %%x
for %%x in (DCD\dsymbol\src\dsymbol\*.d) do set DSYMBOL=!DSYMBOL! %%x
for %%x in (DCD\dsymbol\src\dsymbol\builtin\*.d) do set DSYMBOL=!DSYMBOL! %%x
for %%x in (DCD\dsymbol\src\dsymbol\conversion\*.d) do set DSYMBOL=!DSYMBOL! %%x
for %%x in (containers\src\containers\*.d) do set CONTAINERS=!CONTAINERS! %%x
for %%x in (containers\src\containers\internal\*.d) do set CONTAINERS=!CONTAINERS! %%x

if "%1" == "test" goto test_cmd

@echo on
echo %DMD_FRONTEND_SRC%
%DC% %MFLAGS%^
	%CORE%^
	%STD%^
	%LIBDPARSE%^
	%LIBDDOC%^
	%ANALYSIS%^
	%INIFILED%^
	%DSYMBOL%^
	%CONTAINERS%^
	%DMD_FRONTEND_SRC%^
	%DMD_FRONTEND_SRC2%^
	%DMD_FRONTEND_SRC3%^
	%DMD_FRONTEND_SRC4%^
	%DFLAGS%^
	-I"libdparse\src"^
	-I"DCD\dsymbol\src"^
	-I"containers\src"^
	-I"libddoc\src"^
	-I"libddoc\common\source"^
	-I"dmd\compiler\src"^
	-ofbin\dscanner.exe
goto eof

:test_cmd
@echo on
set TESTNAME="bin\dscanner-unittest"
%DC% %MFLAGS% ^
	%STD%^
	%LIBDPARSE%^
	%LIBDDOC%^
	%INIFILED%^
	%DSYMBOL%^
	%CONTAINERS%^
	%DMD_FRONTEND_SRC%^
	%DMD_FRONTEND_SRC2%^
	%DMD_FRONTEND_SRC3%^
	%DMD_FRONTEND_SRC4%^
	-I"libdparse\src"^
	-I"DCD\dsymbol\src"^
	-I"containers\src"^
	-I"libddoc\src"^
	-I"dmd\compiler\src"^
	-I"dmd\compiler\src\dmd\res"^
	-lib %TESTFLAGS%^
	-of%TESTNAME%.lib
if exist %TESTNAME%.lib %DC% %MFLAGS%^
	%CORE%^
	%ANALYSIS%^
	%TESTNAME%.lib^
	-I"src"^
	-I"inifiled\source"^
	-I"libdparse\src"^
	-I"DCD\dsymbol\src"^
	-I"containers\src"^
	-I"libddoc\src"^
	-I"libddoc\common\source"^
	-I"dmd\compiler\src"^
	-I"dmd\compiler\src\dmd\res"^
	-unittest^
	%TESTFLAGS%^
	-of%TESTNAME%.exe
if exist %TESTNAME%.exe %TESTNAME%.exe

if exist %TESTNAME%.obj del %TESTNAME%.obj
if exist %TESTNAME%.lib del %TESTNAME%.lib
if exist %TESTNAME%.exe del %TESTNAME%.exe

:eof
