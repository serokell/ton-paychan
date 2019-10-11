# SPDX-FileCopyrightText: 2019 Serokell <https://serokell.io>
#
# SPDX-License-Identifier: MPL-2.0

#
# Configure paths
#

ton_src = ../ton

fift_lib = $(ton_src)/crypto/fift/lib
fift_compiler = fift
func_lib = $(ton_src)/crypto/smartcont/stdlib.fc
func_compiler = func

##

export FIFTPATH:=src/cli:src/lib:$(fift_lib)

all: compile

func_opts = -P -O0
paychan_func_src = src/lib/Sign.fc src/lib/Iou.fc src/contract/errors.fc src/lib/Util.fc src/lib/State/Local/StateTags.fc src/lib/State/Local/WaitingBoth.fc src/lib/State/Local/WaitingOne.fc src/lib/State/Local/Open.fc src/lib/State/Local/Terminated.fc src/lib/State/Local/Closing.fc src/lib/State/GlobalState.fc src/lib/State/Util.fc src/lib/request/ReqOps.fc src/lib/Request/Close.fc src/lib/State/State.fc src/lib/Payout.fc src/contract/Handlers/simple_transfer_handler.fc src/contract/Handlers/close_handler.fc src/contract/Handlers/timeout_handler.fc src/contract/paychan.fc

compile: build/paychan.boc

build/paychan.fif: $(paychan_func_src)
	@mkdir -p $(@D)
	$(func_compiler) $(func_opts) -o$@ $(func_lib) $^

build/paychan_write_boc.fif: $(paychan_func_src)
	@mkdir -p $(@D)
	$(func_compiler) $(func_opts) -Wbuild/paychan.boc -o$@ $(func_lib) $(paychan_func_src)

build/paychan.boc: build/paychan_write_boc.fif
	@mkdir -p $(@D)
	$(fift_compiler) -I$(fift_lib) $^

include test/Makefile

clean:
	rm -rf build
