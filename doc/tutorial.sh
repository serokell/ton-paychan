#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2019 Serokell <https://serokell.io>
#
# SPDX-License-Identifier: MPL-2.0

#!/usr/bin/env bash

set -e

#
# Setup env
#

reproducible=0

mkdir alice
mkdir bob

# Test that it is executable and show usage
paychan

runalice () { (set -x; cd alice; "$@") }
runbob () { (set -x; cd bob; "$@") }

#################################################


# Create keys
if [ "$reproducible" -ne 0 ]; then
  echo "Using known key for alice"
  echo 'BFAi1oeAwvWKZ7LB9b7AF/sSR4P8oAnvlTmE0L4JpL0=' | base64 -d > alice/alice.sk
  echo 'UcGtWQSGUx7uuUKmYWUlVL0ikMwMh7XvPcrMWu0owOI=' | base64 -d > alice/alice.pk
  echo "Using known key for bob"
  echo 'vGDas2yT1V2O24G1g1PgiXd3leWByFb8LoFwVdvRh7Y=' | base64 -d > bob/bob.sk
  echo '1lI4QHiiJWiMMGJ1PLaQfVay1edQq0U0RqwGLKiku2A=' | base64 -d > bob/bob.pk
else
  runalice paychan key gen alice
  runbob paychan key gen bob
fi
cp alice/alice.pk bob/
cp bob/bob.pk alice/


# Start the channel
if [ "$reproducible" -ne 0 ]; then
  runalice paychan chan new alice 2 bob 1 86400 0.5 0.1 566
else
  runalice paychan chan new alice 2 bob 1 86400 0.5 0.1
fi
runalice mv paychan.join ../bob/

addr=$(ls alice/*.state | head -n 1)
addr=${addr#alice/}
addr=${addr%.state}
runalice paychan chan info "$addr"

runbob paychan chan join bob alice

# Alice makes payments
runalice paychan payment send "$addr" 0.1
runalice mv paychan.pay ../bob/1.pay

runalice paychan chan info "$addr"

runalice paychan payment send "$addr" 0.2
runalice mv paychan.pay ../bob/2.pay
runalice paychan payment send "$addr" 0.3
runalice mv paychan.pay ../bob/3.pay

runalice paychan chan info "$addr"

# Bob receives payments
runbob mv 1.pay paychan.pay
runbob paychan payment info
runbob paychan payment receive "$addr"

runbob paychan chan info "$addr"

runbob mv 3.pay paychan.pay
runbob paychan payment receive "$addr"

runbob paychan chan info "$addr"

runbob mv 2.pay paychan.pay
runbob paychan payment receive "$addr"

runbob paychan chan info "$addr"

# Bob makes payments
runbob paychan payment send "$addr" 0.15
runbob mv paychan.pay ../alice/1.pay
runbob paychan payment send "$addr" 0.25
runbob mv paychan.pay ../alice/2.pay

# Alice receives one and sends it back
runalice mv 1.pay paychan.pay
runalice paychan payment receive "$addr"
runalice paychan payment send "$addr" 0.15
runalice mv paychan.pay ../bob/
runbob paychan payment receive "$addr"

# The second payment is lost
runalice rm 2.pay

# Sync before closing (optional)
runalice paychan chan sync "$addr"
runalice mv paychan.pay ../bob/
runbob paychan payment receive "$addr"
runbob paychan chan sync "$addr"
runbob mv paychan.pay ../alice/
runalice paychan payment receive "$addr"

# Close the channel
runalice paychan chan info "$addr"
runalice paychan chan close "$addr"

runbob paychan chan info "$addr"
runbob paychan chan close "$addr"
