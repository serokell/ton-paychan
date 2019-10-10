# SPDX-FileCopyrightText: 2019 Serokell <https://serokell.io>
#
# SPDX-License-Identifier: MPL-2.0

.PHONY: test
test: test/fift test/interop

.PHONY:  test/fift
test/fift:
	@find test -name '*Tests.fif' -exec fift -s {} \;

.PHONY:  test/interop
test/interop: test/interop/sign
	# TODO: find a way to silence the VM output
	@find test -name '*Interop.fif' | xargs fift -v 0 -s

.PHONY:  test/interop/sign
test/interop/sign: test/lib/signInterop.asm.gen

test/lib/signInterop.asm.gen: src/lib/Sign.fc test/lib/signInterop.fc
	@func -P -o$@ $(func_lib) $^

include test/lib/State/GlobalStateRoundtrip/Makefile
include test/lib/State/Local/WaitingOneRoundtrip/Makefile
include test/lib/State/Local/OpenRoundtrip/Makefile
include test/lib/State/Local/ClosingRoundtrip/Makefile

.PHONY: test/state
test/state : test/state/global test/state/local

.PHONY: test/state/global
test/state/global: test/lib/State/GlobalStateRoundtrip/roundtripTest.fif

.PHONY: test/state/local
test/state/local : test/state/local/waitingOne test/state/local/open test/state/local/closing

.PHONY: test/state/local/waitingOne
test/state/local/waitingOne: test/lib/State/Local/WaitingOneRoundtrip/roundtripTest.fif

.PHONY: test/state/local/open
test/state/local/open: test/lib/State/Local/OpenRoundtrip/roundtripTest.fif

.PHONY: test/state/local/closing
test/state/local/closing: test/lib/State/Local/ClosingRoundtrip/roundtripTest.fif
