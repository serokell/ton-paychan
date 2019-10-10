

build/paychan-init.boc: scripts/paychan-init.fift build/paychan.boc
	$(fift_compiler) -s scripts/paychan-init.fift 0


build/msg/simple-transfer.boc: scripts/simple-transfer-req.fif
	$(fift_compiler) $^

build/msg/simple-transfer-pk1.boc: scripts/simple-transfer-req.fif
	$(fift_compiler) -s $^ "key1.pk" $@

build/msg/simple-transfer-pk2.boc: scripts/simple-transfer-req.fif
	$(fift_compiler) -s $^ "key2.pk" $@

