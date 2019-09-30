# SPDX-FileCopyrightText: 2019 Serokell <https://serokell.io>
#
# SPDX-License-Identifier: MPL-2.0

fift = fift -I $(fift_lib):src/lib

.PHONY: test
test: test/fift test/interop

.PHONY:  test/fift
test/fift:
	@find test -name '*Tests.fif' | xargs $(fift) -s

.PHONY:  test/interop
test/interop: test/interop/sign
	# TODO: find a way to silence the VM output
	@find test -name '*Interop.fif' | xargs $(fift) -v 0 -s

.PHONY:  test/interop/sign
test/interop/sign: test/lib/signInterop.asm.gen

test/lib/signInterop.asm.gen: src/lib/Sign.fc test/lib/signInterop.fc
	@func -P -o$@ $(func_lib) $^
