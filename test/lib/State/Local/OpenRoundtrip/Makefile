# SPDX-FileCopyrightText: 2019 Serokell <https://serokell.io>
#
# SPDX-License-Identifier: MPL-2.0

.PHONY: test/lib/State/Local/OpenRoundtrip/roundtripTest.fif
test/lib/State/Local/OpenRoundtrip/roundtripTest.fif: test/lib/State/Local/OpenRoundtrip/roundtripTest.asm.gen
	$(fift_compiler)  -I$(fift_lib):src/lib $@

test/lib/State/Local/OpenRoundtrip/roundtripTest.asm.gen: src/lib/Util.fc src/contract/errors.fc src/lib/State/Local/StateTags.fc src/lib/State/Local/Open.fc test/lib/State/Local/OpenRoundtrip/roundtripTest.fc
	$(func_compiler) -P -o$@ $(func_lib) $^
