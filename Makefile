# SPDX-FileCopyrightText: 2019 Serokell <https://serokell.io>
#
# SPDX-License-Identifier: MPL-2.0

#
# Configure paths
#

ton_src = ../ton

fift_lib = $(ton_src)/crypto/fift/lib
func_lib = $(ton_src)/crypto/smartcont/stdlib.fc
func_compiler = func

##

export FIFTPATH:=src/lib:$(fift_lib)

all: compile

func_opts = -P -O0
paychan_func_src = src/lib/Sign.fc src/lib/Iou.fc src/lib/Util.fc src/lib/State/Local/StateTags.fc src/lib/State/Local/WaitingBoth.fc src/lib/State/Local/WaitingOne.fc src/lib/State/Local/Open.fc src/lib/State/Local/Closing.fc src/lib/State/GlobalState.fc src/lib/request/SimpleTransfer.fc src/lib/Request/Close.fc src/lib/State/State.fc src/lib/Payout.fc src/contract/Handlers/simple_transfer_handler.fc src/contract/Handlers/close_handler.fc src/contract/paychan.fc
paychan_out = build/paychan.fif

compile : $(paychan_out)

$(paychan_out): $(paychan_func_src)
	@mkdir -p $(@D)
	$(func_compiler) $(func_opts) -o$(paychan_out) $(func_lib) $(paychan_func_src)

include test/Makefile
