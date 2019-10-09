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

The contract starts in the “waiting” state, which means that it is waiting
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

### Message format

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

### Message processing

TODO

## Contract logic

The contract’s state is described by the following data type:

```haskell
data PayChanState = MkPayChanState
  { globalState :: GlobalState
  , localState :: LocalState
  }

data GlobalState = MkGlobalState
  { parties :: (PublicKey, PublicKey)
  , shares :: (UInt120, UInt120)
  , timeout :: UInt32
  , fineAmount :: Int120
  , nonce :: UInt64  -- ^ Set to deployment time-stamp to change the hash
  }

data LocalState
  = MkStateWaitingBoth  -- ^ Waiting for shares
  | MkStateWaitingOne Address PublicKey  -- ^ Waiting for the second share
  | MkStateOpen OpenState  -- ^ The channel is open and can be used
  | MkStateClosing OpenState ClosingState  -- ^ One party requested the channel to close
  | MkStateDispute OpenState DisputeState  -- ^ One of the party started a dispute

data OpenState = MkOpenState (Address, Address)

data ClosingState = MkClosingState
  { requester :: PublicKey  -- ^ Who requested the channel closed
  , openState :: OpenState  --^ Details from the previous state
  , request :: CloseRequest  -- ^ Details of the request provided
  , timestamp :: Timestamp  -- ^ When the channel was requested to close
  }

data DisputeState = MkDisputeState
  { starter :: PublicKey  -- ^ Who started the dispute
  , request :: DisputeRequest  -- ^ Details of the request provided
  , timestamp :: Timestamp  -- ^ When the dispute was started
  }
```

Users can make the following requests:

```haskell
data Request
  | MkRequestClose CloseRequest
  | MkRequestDispute DisputeRequest
  | MkRequestDisputeOk
  | MkRequestDisputeBad DisputeBadRequest
  | MkRequestTimeout

data CloseRequest = MkCloseRequest
  { payout :: Int121  -- ^ Requested payout
  , iou :: Maybe Iou  -- ^ Last IOU from the other party
  }

data DisputeRequest = MkDisputeRequest
  { closeRequest :: CloseRequest
  , badIou :: Iou  -- ^ Invalid IOU from the other party
  }

data DisputeBadRequest = MkDisputeRequest
  { goodIou :: Iou  -- ^ IOU from the other party that proves them wrong
  , closeRequest :: CloseRequest
  }
```

### Initialisation and waiting for the first share (`MkStateWaitingBoth`)

The contract is initialised with its global state (which plays the role of
configuration) and local state `MkStateWaitingBoth`. Transitions possible:

* One party contributes their share -> `MkStateWaitingOne`. The new state
  records the address that the funds arrived from (it will be used for the
  payout in the end) and the identity of the other party we are waiting for.
* The deployer of the contract requests it destroyed.

### Waiting for the second share (`MkStateWaitingOne`)

One of the parties has contributed their share and the contract waiting for
the other one. Possible transitions:

* The first party requests a refund (`MkDisputeOk`) -> their share is returned
  back to their address and the contract is destroyed.
* The second party contributes their share -> `MkStateOpen`. The address
  of the second party is recorded as well.

### The channel is open (`MkStateOpen`)

Now all transactions happen off-chain. The parties exchange their IOUs
until they decide to close the channel or one of the parties requests
arbitration. Possible transitions:

* One party requests the channel closed (`MkRequestClose`) -> `MkStateClosing`.
  (If the `payout` value is impossible, the request is rejected.)
  The contract remembers the requester and the IOU they provided, if any, but
  it is not verified yet. Current time-stamp is also recorded.
* One party disputes an incorrect IOU from the other (`MkRequestDispute`) ->
  `MkStateDispute`. Again, all details of the request, include the time-stamp,
  are remembered.

### The channel is closing (`MkStateClosing`)

The contract is waiting for a confirmation from the other party. Transitions:

* The other party requests the channel to be closed (`MkRequestClose`) and the
  requested payouts agree with each other exactly, that is, their sum is 0.
  In this case the payout is performed according to the requests and the
  contract is destroyed. “According to the requests” means that the first party
  gets the amount of tokens equal to their initial share plus their request;
  and the second party gets the amount of tokens equal to their initial share
  minus the first party’s request (or plus their request, which is the same).
  If one of the requested payout values was negative and its absolute value
  is more than the corresponding party’s contributed share, the computation
  proceeds as if the requested payout was equal to this share’s value negated,
  and the party is fined.
* The other party requests the channel to be closed (`MkRequestClose`) and the
  requested payouts do not agree with each other exactly. In this case the
  final distribution is computed as follows, assuming both IOUs are properly signed:
    * `owes1`, the amount owed by the first party, is computed as the maximum of
      `(iou - payout)` from their request and `iou` from the second party’s
      request.
    * `owes2`, the amount owed by the second party is computed symmetrically.
    * The payout proceeds as if the requested balances were `(owes2 - owes1)`
      and `(owes1 - owes2)` respectively.
  If any of the IOUs is was not provided, it is assumed that it contains zeroes
  in its `iou` and `uome` fields.
  If one of the IOUs is not properly signed, the computation proceeds as if
  the corresponding party did not provide an IOU at all, and in addition
  this party is fined.
  If both IOUs are not properly signed, the contract transitions back to
  `MkStateOpen`.
* The other party disappears and the original requester forces the channel
  to close (`MkRequestTimeout`). If the amount of time given by `timeout` has
  passed, the payment is made according to the request and the other party
  is fined. Otherwise the request is rejected. (TODO: charge for incorrect
  requests.)

If the contract is destroyed, the locked fines amounts are returned to their
respective parties, unless one of the was fined in the process, in which case
both locked amounts are transferred to the honest party.


### A dispute is happening (`MkStateDispute`)

One of the parties reported incorrect behaviour of the other party. Only one
time of incorrect behaviour can be detected: the second party sent to the
first one an IOU that indicated that the first party transferred more than they
ever agreed to. In order to contend, the second party has to present an IOU
that shows that the first party indeed transferred to them that much.
Transitions:

* The second party agrees that the dispute is valid (`MkRequestDisputeOk`).
  The payout is made as requested and the offending party is fined.
* The second party disagrees with the dispute (`MkRequestDisputeBad`).
  They have to provide any IOU signed by the first party that shows that they
  transferred in total at least as much as shown in the allegedly bad IOU.
  If they succeed in doing so, the payout is made according to their new
  request and the first party is fined. Otherwise the payout is made according
  to the original request and the second party is fined.
* The second party does not respond to the dispute (`MkRequestTimeout`).
  Same as with closing.


## TODO

* Figure out how to punish parties for incorrect requests
* Set gas limit to make sure the locked amounts are never spent for gas
* Send the extra gas-tokens somewhere when closed


## Further work

* Make optimisations for uni-directional channels.
* Allow parties to increase their shares as they go.
* Penalise parties by skewing the distribution in the end.
