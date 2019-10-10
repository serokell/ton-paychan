.PHONY: test/lib/State/Local/WaitingOneRoundtrip/roundtripTest.fif
test/lib/State/Local/WaitingOneRoundtrip/roundtripTest.fif: test/lib/State/Local/WaitingOneRoundtrip/roundtripTest.asm.gen
	$(fift_compiler)  -I$(fift_lib):src/lib $@

test/lib/State/Local/WaitingOneRoundtrip/roundtripTest.asm.gen: src/lib/Util.fc src/lib/State/Local/StateTags.fc src/lib/State/Local/WaitingOne.fc test/lib/State/Local/WaitingOneRoundtrip/roundtripTest.fc
	$(func_compiler) -P -o$@ $(func_lib) $^
