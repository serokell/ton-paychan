# SPDX-FileCopyrightText: 2019 Serokell <https://serokell.io>
#
# SPDX-License-Identifier: MPL-2.0

#
# Configure paths
#

ton_src = ../ton

fift_lib = $(ton_src)/crypto/fift/lib
func_lib = $(ton_src)/crypto/smartcont/stdlib.fc

##

export FIFTPATH:=src/lib:$(fift_lib)

all:
	@echo "No buildable targets defined yet!"

func_opts = -O0
paychan_func_src = src/lib/Sign.fc src/lib/Iou.fc src/contract/paychan.fc
paychan_out = out/paychan.fif

compile:
	./func $(func_opts) -o$(paychan_out) $(func_lib) $(paychan_func_src)

include test/Makefile
