.PHONY: test/lib/State/Local/ClosingRoundtrip/roundtripTest.fif
test/lib/State/Local/ClosingRoundtrip/roundtripTest.fif: test/lib/State/Local/ClosingRoundtrip/roundtripTest.asm.gen
	$(fift_compiler)  -I$(fift_lib):src/lib $@

test/lib/State/Local/ClosingRoundtrip/roundtripTest.asm.gen: src/lib/Util.fc src/contract/errors.fc src/lib/State/Local/StateTags.fc src/lib/State/Local/Closing.fc test/lib/State/Local/ClosingRoundtrip/roundtripTest.fc
	$(func_compiler) -P -o$@ $(func_lib) $^
