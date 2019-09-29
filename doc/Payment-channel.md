<!--
   - SPDX-FileCopyrightText: 2019 Serokell <https://serokell.io>
   -
   - SPDX-License-Identifier: MPL-2.0
   -->

# TON Payment Channels Specification


## Overview

Suppose two parties, Alice and Bob, would like to make a series of payments
to each other, and for efficiency reasons they decide to perform them
through a payment channel rather than on-chain.

They agree on the parameters of the channel, such as the shares they have
to contribute (which will bound how much each of them can owe to each other
in the process), inactivity timeout, and misbehaviour fine. Then the payment
channel contract is preconfigured and deployed to the blockchain network
(this can be done either by Alice, or bob, or someone else).

The contract starts in the “initialising” state, which means that it is waiting
for initial commitments from both parties. Alice and Bob each have to send
to the contract the amount of tokens equal to their share, plus and extra
amount that will be locked in order to be used as a fine payment in case of
misbehaviour. After one of the parties makes their transaction, they can cancel
contract initialisation and destroy it any time until the other party sends
their transaction as well. After this the tokens are locked in the contract
and the payment channel is considered open.

Now if one of the parties wants to send a payment to the other, they prepare
a special IOU message that contains the transaction amount and two values that
record how much each of them have transferred to the other so far.
The message is signed and transferred over any communication medium that
Alice and Bob prefer to use. Including the total amounts that they owe to each
other in every message is necessary to make sure that if, at any point, one
of the parties disappears, the other has a message signed by them indicating
the last funds distribution they agreed to.

These micro-transactions can be sent at any time and as many of them as the
parties wish, as long as the data types used for keeping track of their
liabilities do not overflow and as long as they stay within the bounds
they committed to during contract configuration, that is, there have to
be enough funds stored in the contract. Notice that the channel is
bi-directional and receiving a payment _reduces_ the debt of the receiver,
therefore, as long as the mutual debts are balanced and stay within the
allowed bounds the channel can remain open for a prolonged period of time.

It is recommended that parties acknowledge the receipt of each micro-payment,
for example, this can happen naturally by the party performing the services
that it was paid for; however the security of the channel does not depend
on this. It is also not a requirement that the IOU messages are delivered
in order, or, actually, delivered at all. Since every IOU message carries
all the information about current debts, it is enough to receive the last
one before closing the channel.

When Alice and Bob expect no further micro-transactions, they start closing
the channel. It is recommended that they exchange two final IOU messages
sending 0 to each other in order to confirm that they are in agreement on
final amounts owed to each other. When ready, Alice sends to the contract
a payout request and attaches the last IOU she received from Bob. After this
she is not allowed to send any non-zero payment to Bob. Now Bob has a fixed
amount of time to either confirm that he agrees with the distribution
proposed or protest. If he agrees, he sends a confirmation to the contract
and it distributes the funds according to the distribution proposed by Alice;
if he believes Alice owes him more than she stated, he can submit a more
recent IOU from Alice showing a larger amount, in which case the contract
will perform the distribution according to this newer IOU and fines Alice.
In case Bob does neither, after the fixed time passes, Alice can request
the contract to go ahead and distribute the funds according to her proposal
and fine Bob.


## Off-chain protocol

The following `Iou` data type specified the wire-format of the IOU message:

```haskell
data Signed a = MkSigned
  { payload :: a  -- ^ Arbitrary cell-serialisable data
  , signature :: Signature  -- ^ Signature for the payload
  }
-- serialisation:
-- / signature (= 512) /
-- \ bits              \
-- ref1 = payload


data IouPayload = MkIouPayload
  { channel :: ContractAddress  -- ^ Address of the payment channel contract
  , amount :: UInt120  -- ^ This micro-payment amount
  , iou :: UInt248  -- ^ Total transfered to the other party
  , uome :: UInt248  -- ^ Total received from the other party
  }
-- serialisation:
-- / channel (<= 301) / amount (<= 124) / iou (<= 253) / uome (<= 253) /
-- \ std_addr         \ varuint16       \ varuint32    \ varuint32     \

type Iou = Signed IouPayload
```

The channel address is included as a form of replay protection; it guarantees
that each particular IOU can be used only in the context of a single channel.
No other replay protection is necessary, since the iou and uome fields are
non-decreasing and thus naturally play the role of never repeating sequence
numbers.


