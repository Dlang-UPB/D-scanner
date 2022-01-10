# D-Scanner fork that uses dmd as a library (WIP)

D-Scanner is a tool for analyzing D source code

### Building and installing

First, make sure that you have fetched the upstream: git@github.com:dlang-community/D-Scanner.git

```
git remote add upstream git@github.com:dlang-community/D-Scanner.git
git fetch upstream
```

Secondly, make sure that you have all the source code. Run ```git submodule update --init --recursive```
after cloning the project.

To build D-Scanner, run ```make``` (or the build.bat file on Windows).
The build time can be rather long with the -inline flag on front-end versions
older than 2.066, so you may wish to remove it from the build script. The
makefile has "ldc" and "gdc" targets if you'd prefer to compile with one of these
compilers instead of DMD. To install, simply place the generated binary (in the
"bin" folder) somewhere on your $PATH.

### Testing
Testing does not work with DUB.
Under linux or OSX run the tests with `make test`.
Under Windows run the tests with `build.bat test`.
