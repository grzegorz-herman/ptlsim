INCFLAGS = -I. -DBUILDHOST="`hostname`" -DSVNREV="0" -DSVNDATE="0"
CFLAGS = -O3 -fPIE -ggdb -fno-tree-loop-distribute-patterns -fomit-frame-pointer -pipe -march=k8 -falign-functions=16 -funroll-loops -funit-at-a-time -minline-all-stringops
CFLAGS += -fno-trapping-math -fno-stack-protector -funroll-loops -mpreferred-stack-boundary=4 -fno-strict-aliasing -fno-stack-protector -Wreturn-type -Wno-narrowing -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0
CFLAGS += -D__PTLSIM_OOO_ONLY__
CXXFLAGS = $(CFLAGS)
CXXFLAGS += -fno-exceptions -fno-rtti

BASEOBJS := superstl.o config.o mathlib.o syscalls.o
STDOBJS := glibc.o
COMMONOBJS := lowlevel-64bit.o ptlsim.o kernel.o mm.o ptlhwdef.o decode-core.o decode-fast.o decode-complex.o decode-x87.o decode-sse.o uopimpl.o datastore.o injectcode-64bit.o seqcore.o $(BASEOBJS) klibc.o ptlsim.dst.o
OOOOBJS := branchpred.o dcache.o ooocore.o ooopipe.o oooexec.o 

LIBGCC := $(shell $(CC) -print-libgcc-file-name)

TOPLEVEL := ptlsim ptlstats ptlcalls.o #cpuid

all : $(TOPLEVEL)
	@echo "Compiled succesfully"

ptlsim : crti.o $(COMMONOBJS) $(OOOOBJS) ptlsim.dst.o $(LIBGCC) crtn.o
	$(CXX) $^ -static -Wl,--allow-multiple-definition -Wl,-T -Wl,ptlsim.lds -Wl,-e -Wl,ptlsim_preinit_entry -o $@

ptlsim.dst.o: ptlsim.dst
	objcopy -I binary -O elf64-x86-64 -B i386 --rename-section .data=.dst,alloc,load,readonly,data,contents ptlsim.dst ptlsim.dst.o

ptlsim.dst: dstbuild stats.h ptlhwdef.h ooocore.h dcache.h branchpred.h decode.h $(BASEOBJS) $(STDOBJS) datastore.o ptlhwdef.o
	$(CXX) $(CXXFLAGS) $(INCFLAGS) -E -C stats.h > stats.i
	cat stats.i | ./dstbuild PTLsimStats > dstbuild.temp.cpp
	$(CXX) $(CXXFLAGS) $(INCFLAGS) -DDSTBUILD -include stats.h dstbuild.temp.cpp $(BASEOBJS) $(STDOBJS) datastore.o ptlhwdef.o -o dstbuild.temp
	./dstbuild.temp > ptlsim.dst
	rm -f dstbuild.temp destbuild.temp.cpp stats.i

injectcode-64bit.o: injectcode.cpp
	$(CXX) $(CXXFLAGS) $(INCFLAGS) -m64 -O99 -fomit-frame-pointer -c $< -o $@

ptlstats : ptlstats.o datastore.o ptlhwdef.o $(BASEOBJS) $(STDOBJS)
	$(CXX) $(CXXFLAGS) -fPIE $^ -O2 -o $@

cpuid : cpuid.o $(BASEOBJS) $(STDOBJS)
	$(CXX) $(CXXFLAGS) $^ -O2 -o $@

%.o : %.cpp
	$(CXX) $(CXXFLAGS) $(INCFLAGS) -c $< -o $@

%.o : %.S
	$(CC) $(CFLAGS) $(INCFLAGS) -c $< -o $@

%.o : %.c
	$(CC) -std=c99 $(CFLAGS) $(INCFLAGS) -c $< -o $@

clean :
	rm -f $(TOPLEVEL) $(BASEOBJS) $(STDOBJS) $(COMMONOBJS) $(OOOOBJS)
