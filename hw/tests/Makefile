##
## Toplevel Makefile
##

USE_BUILDCACHE=1

TESTS += test_blocksync
TESTS += test_decoder
TESTS += test_descrambler
TESTS += test_encoder
TESTS += test_gearbox_40_66
TESTS += test_gearbox_66_40
TESTS += test_pcs
TESTS += test_scrambler
#TESTS += test_phy   ### not used, as PMA cannot be tested using bsim
#TESTS += test_dtp  ### last dtp test does not terminate

all: $(addprefix sim/,$(TESTS))
	echo $(TESTS)

sim/% : %
	mkdir -p sim
	USE_BUILDCACHE=$(USE_BUILDCACHE) make -C $< gen.bluesim
	USE_BUILDCACHE=$(USE_BUILDCACHE) make -C $< build.bluesim
	USE_BUILDCACHE=$(USE_BUILDCACHE) make -C $< run.bluesim

clean:
	rm -rf sim
