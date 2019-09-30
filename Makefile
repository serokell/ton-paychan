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

include test/Makefile
