# SPDX-FileCopyrightText: 2019 Serokell <https://serokell.io>
#
# SPDX-License-Identifier: MPL-2.0

#
# Configure paths
#

ton_src = ../ton

fift_lib = $(ton_src)/crypto/fift/lib
func_lib = $(ton_src)/crypto/smartcont/stdlib.fc

func_opts = -O0

paychan_func_src = src/lib/Sign.fc src/lib/Iou.fc src/contract/paychan.fc

##

export FIFTPATH:=src/lib:$(fift_lib)

all:
	@echo "No buildable targets defined yet!"

compile:
  # for now just outputting to stdout
	func $(func_opts) $(func_lib) $(paychan_func_src)

include test/Makefile
