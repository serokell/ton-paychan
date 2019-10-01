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

out:
	mkdir out

func_opts = -P -O0
paychan_func_src = src/lib/Sign.fc src/lib/Iou.fc src/contract/paychan.fc
paychan_out = out/paychan.fif

compile : $(paychan_out)

$(paychan_out): out $(paychan_func_src) 
	$(func_compiler) $(func_opts) -o$(paychan_out) $(func_lib) $(paychan_func_src)

include test/Makefile
