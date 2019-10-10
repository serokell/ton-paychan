.PHONY: test/lib/State/GlobalStateRoundtrip/roundtripTest.fif
test/lib/State/GlobalStateRoundtrip/roundtripTest.fif: test/lib/State/GlobalStateRoundtrip/roundtripTest.asm.gen
	$(fift_compiler)  -I$(fift_lib):src/lib $@

test/lib/State/GlobalStateRoundtrip/roundtripTest.asm.gen: src/lib/Util.fc src/lib/State/GlobalState.fc test/lib/State/GlobalStateRoundtrip/roundtripTest.fc
	$(func_compiler) -P -o$@ $(func_lib) $^
