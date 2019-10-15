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
to the contract the amounts of tokens equal to their shares, plus extra
deposits that will be locked in order to be used as a fine payment in case of
misbehaviour. Once both parties contribute their shares, the tokens become
locked in the contract and the payment channel is considered open.

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

It is recommended that parties acknowledge the receipt of each micro-payment
(for example, this can happen naturally by the party performing the services
that they were paid for); however the security of the channel does not depend
on this. It is also not a requirement that the IOU messages are delivered
in order, or, actually, delivered at all. Since every IOU message carries
all the information about current debts, it is enough to receive the last
one before closing the channel.

When Alice and Bob expect no further micro-transactions, they start closing
the channel. It is recommended that they exchange two final IOU messages
sending 0 to each other in order to confirm that they are in agreement on
final amounts owed to each other. When ready, Alice sends to the contract
a payout request and attaches the last IOU she received from Bob. Then Bob
has a fixed amount of time to either confirm that he agrees with the distribution
proposed or, if it is not the case, propose another distribution.

In any case, since the distribution proposals are supported by IOUs signed
by the other party, the payment channel smart-contract will be able to
decide on a fair distribution that will guarantee that both parties receive
at least as much funds as they expect to receive, based on the incoming
payments that they saw.


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
  { channel :: Address  -- ^ Address of the payment channel contract
  , amount :: UInt120  -- ^ This micro-payment amount
  , iou :: UInt248  -- ^ Total transfered to the other party
  , uome :: UInt248  -- ^ Total received from the other party
  }
-- serialisation:
-- / channel (= 8 + 256) / amount (<= 124) / iou (<= 253) / uome (<= 253) /
-- \ uint8 + uint256     \ varuint16       \ varuint32    \ varuint32     \

type Iou = Signed IouPayload
```

The channel address is included as a form of replay protection; it guarantees
that each particular IOU can be used only in the context of a single channel.
No other replay protection is necessary, since the iou and uome fields are
non-decreasing and thus naturally play the role of never repeating sequence
numbers.

### Message processing

Each party shall maintain their own view of the state of the payment protocol:

```
data CliState = MkCliState
  { chanAddr :: ContractAddress
  , chanGlobalState :: GlobalState  -- ^ See below.
  , paymentsState :: PaymentsState
  }

data PaymentsState = MkPaymentsState
  { weOwe :: UInt248  -- ^ How much we owe in total
  , theyOwe :: UInt248  -- ^ How much we are owed in total
  , lastIou :: Maybe Iou  -- ^ Last IOU we received from them
  , missingAmount :: UInt248  -- ^ Value in payments detected as missing
  }
```

The `weOwe` and `theyOwe` fields serve dual purpose:

1. They establish the actual amounts owed by the parties to each other.
2. They function as a vector clock and allow to establish a happened-before
   relation on IOU messages.

Due to the second item above, the micro-payment protocol is fully asynchronous,
does not require any confirmations or that the payments arrive in order.

When a new IOU arrives from the other party, the following steps are performed:

1. Check that their `uome` field of the IOU is not greater than our recorded
   `weOwe` value. It is impossible that a honest party would think that we owe
   them more than what we think we ever promised, thus it implies that the
   other party is trying to cheat or their state is corrupted, so the IOU
   has to be rejected.
2. Check that the new value of `(iou - uome)` is not greater than their share
   contributed to the channel. Otherwise reject the IOU.
3. Compare their `iou` with our `theyOwe`:
    * If it is greater or equal, then this is a new transaction. Check that
      `amount` equals `iou - theyOwe`. If it is greater, warn the user
      that some incoming payment that happened before this one went missing
      and add the difference to `missingAmount`. If it is smaller, reject.
      Then set `theyOwe := iou`.
    * If it is less, then this is one of the previously missing transactions.
      Check that `amount` is not greater than `missingAmount`, otherwise reject.
      Subtract `amount` from `missingAmount`.

To make a new micro-payment:

1. Check that the remaining share is enough for the payment.
2. Add the desired amount to `weOwe`.
3. Prepare a new IOU with the updated values and send it.

In order to close a channel, the party submits a close request requesting
a payout of amount equal to `theyOwe - weOwe` together with the last
IOU they received, if any.


## Contract logic

The contract’s state is described by the following data type:

```haskell
data PayChanState = MkPayChanState
  { globalState :: GlobalState
  , localState :: LocalState
  }

-- | Channel config.
data GlobalState = MkGlobalState
  { parties :: (PublicKey, PublicKey)
  , shares :: (UInt120, UInt120)
  , timeout :: UInt32  -- ^ Inactivity timeout
  , fineAmount :: UInt120  -- ^ Fine for inactivity
  , nonce :: UInt64  -- ^ Set to deployment time-stamp to change the hash
  }

data LocalState
  = MkStateWaitingBoth  -- ^ Waiting for shares
  | MkStateWaitingOne Address PublicKey  -- ^ Waiting for the second share
  | MkStateOpen OpenState  -- ^ The channel is open and can be used
  | MkStateClosing OpenState ClosingState  -- ^ One party requested the channel to close
  | MkStateTerminated  -- ^ Unreachable state, indicates the contract was destoyed

data OpenState = MkOpenState (Address, Address)

data ClosingState = MkClosingState
  { requester :: PublicKey  -- ^ Who requested the channel closed
  , openState :: OpenState  --^ Details from the previous state
  , request :: CloseRequest  -- ^ Details of the request provided
  , timestamp :: Timestamp  -- ^ When the channel was requested to close
  }
```

Users can make the following requests:

```haskell
-- | Wrapper around the request that contains authentication details
data RequestMessage = RequestMessage
  { reqOp :: UInt32  -- ^ Request identifier
  , pkIndex :: UInt1  -- ^ `0` for party 1 and `1` for party 2
  , contractAddr :: Address
  , signature :: Signature
  , reqBody :: Request
  }
-- serialisation:
-- / reqOp (= 32) / pkIndex (= 1) / contractAddr (= 8 + 256) / signature (= 512) /
-- \ std_addr     \ uint1         \ uint8 + uint256          \ bits              \
-- ref1 = reqBody (optional)

data Request
  = MkRequestJoin  -- ^ reqOp = 1
  | MkRequestClose CloseRequest  -- ^ reqOp = 2
  | MkRequestTimeout  -- ^ reqOp = 3
-- serialisation:
-- reqOp is serialised as part of RequestMessage
-- the argument, if present, is stored as reqBody


data CloseRequest = MkCloseRequest
  { payout :: Int121  -- ^ Final channel settlement amount, in other words
                           how much the other party owes to the requester
  , iou :: Maybe Iou  -- ^ Last IOU from the other party
  }
```

### Initialisation and waiting for the first share (`MkStateWaitingBoth`)

The contract is initialised with its global state (which plays the role of
configuration) and local state `MkStateWaitingBoth`. Transitions possible:

* One party contributes their share (`MkRequestJoin`) -> `MkStateWaitingOne`.
  First, the contract check that the amount contributed is enough, that is,
  it is not smaller than this party’s share plus the fine deposit, otherwise
  the transaction is rejected.
  The new state records the address that the funds arrived from
  (it will be used for the payout in the end) and the identity of the
  other party we are waiting for.
  The amount equal to the requester’s share plus deposit is reserved.
* The deployer of the contract requests it terminated (`MkRequestTimeout`) ->
  `MkStateTerminated`.

### Waiting for the second share (`MkStateWaitingOne`)

One of the parties has contributed their share and the contract waiting for
the other one. Possible transitions:

* The first party requests a refund (`MkRequestTimeout`) -> `MkStateTerminated`.
* The second party contributes their share (`MkRequestJoin`) -> `MkStateOpen`.
  If the amount is smaller than the party’s share plus the fine deposit, the
  transaction is rejected. Otherwise, the address of the second party is recorded.
  The amount equal to the same of the two shares plus two deposits is reserved.

### The channel is open (`MkStateOpen`)

Now all transactions happen off-chain. The parties exchange their IOUs
until they decide to close the channel or one of the parties requests
arbitration. Possible transitions:

* One party requests the channel closed (`MkRequestClose`) -> `MkStateClosing`.
  (If payout with the given `payout` value is impossible, the request is rejected.)
  The contract remembers the requester and the IOU they provided, if any, but
  it is not verified yet. Current time-stamp is also recorded.

### The channel is closing (`MkStateClosing`)

The contract is waiting for a confirmation from the other party. Transitions:

* The other party requests the channel to be closed (`MkRequestClose`) and the
  requested payouts agree with each other exactly, that is, their sum is 0 ->
  `MkStateTerminated`.
  In this case the payout is performed according to the requests and the
  contract is destroyed. “According to the requests” means that the first party
  gets the amount of tokens equal to their initial share plus their request;
  and the second party gets the amount of tokens equal to their initial share
  minus the first party’s request (or plus their request, which is the same).
  If one of the requested payout values was negative and its absolute value
  was more than the corresponding party’s contributed share, the computation
  proceeds as if the requested payout was equal to this share’s value negated,
  and the party is fined.
* The other party requests the channel to be closed (`MkRequestClose`) and the
  requested payouts do not agree with each other exactly.
  In this case the final distribution is computed as follows:
    * `owes1`, the amount owed by the first party, is computed as the maximum of
      `(iou - payout)` from their request and `iou` from the second party’s
      request.
    * `owes2`, the amount owed by the second party is computed symmetrically.
    * The payout proceeds as if the requested balances were `(owes2 - owes1)`
      and `(owes1 - owes2)` respectively.
  If either of the IOUs was not provided, it is assumed that it contains zeroes
  in its `iou` and `uome` fields.
  If either of the IOUs is not properly signed, the computation proceeds as if
  the corresponding party did not provide an IOU at all, and in addition
  this party is fined.
  If both IOUs are not properly signed, the contract transitions back to
  `MkStateOpen`.
* The other party disappears and the original requester forces the channel
  to close (`MkRequestTimeout`). If the amount of time given by `timeout` has
  passed -> `MkStateTerminated`, where the payment the disappeared party
  is fined and the payment proceeds as if they submitted a close request
  with a zero requested payout and no IOU.
  Otherwise the request is rejected.

### Terminating the contract (`MkStateTerminated`)

When the contract is destroyed, the following happens:

* If the contract is terminated before transition to `MkStateOpen`, the party
  that contributes its share gets it back together with their fine deposit.
* If the contract was closed correctly, the shares are redistributed according
  to the `payout` values provided by the parties and. The fine deposits are
  refunded if neither party was fined, or, if one of the parties was fined,
  they get both deposits.
* Any remaining funds are distributed among the two parties proportional to
  their shares.


## Fuelling the contract

Paying for the gas consumption of the contract and especially the storage
costs incurred by the contract is outside the scope of this specification.

* The contract does not `ACCEPT` incoming external messages and does not process
  them in any way.
* When processing incoming internal messages, the contract does not alter
  the default gas limit, which means that it will never spend more than the
  value attached to the message, therefore message processing costs are borne by
  each party individually for the messages they submit.
* The contract will always accept any “extra” funds sent to it with simple
  transfer messages. On termination, all remaining funds are distributed between
  the parties in an unspecified way (current implementation sends everything to
  the first party).
* The contract logic does not take into account the storage costs,
  therefore it is possible that the final payout will fail if funds go below
  the required level; the parties are expected to agree with each other on
  the matter of covering the storage costs and should make sure that
  there are enough funds before closing the contract and refill it by simple
  transfer messages, if necessary.
* When receiving the shares of the parties, the contract must make sure that
  the right amount of funds will end up being locked in it _after_ the message
  is processed. In order to do so, it uses `RAWRESERVE` reserving the amount
  it expects to have in the end, so that if it goes below this level, the
  transaction fails.


## Correctness

What follows is not a rigorous mathematical proof of the correctness of the
protocol, but rather an attempt for a somewhat formal intuitive explanation.

### No unexpected charges

_When the channel is closed and the funds are distributed, a party will receive
at least as much (or spend at most as little) as they expect._

* The party requests a payout of size `theyOwe - weOwe`. Both values come from
  its local state: `theyOwe` is the maximum of `iou` values over all IOUs
  received, while `weOwe` is the true sum of all payments sent by this party.
* In case the other party requests a matching payout, the contract will perform
  no further checks and make transfers according to this distribution,
  so every party will get exactly what they expect to get.
* Otherwise conflict resolution starts. The contract computes the value owed by
  this party as the maximum of `(iou - payout)` from their request and `iou` from
  the other party’s request. The first value equals `(theyOwe - (theyOwe - weOwe))
  = weOwe`, while `iou` in the other party’s request cannot be larger than
  `weOwe` as it has to be properly signed and no honest party will sign
  an IOU indicating that they owe more than `weOwe` stored in their state.
  The amount owed by the other party is computed as a similar maximum and thus
  will not be smaller than `iou` from the current party’s request, which is
  equal to `theyOwe` from the current party’s state, therefore the final payout
  computed by the contract for this party will be greater or equal to
  `theyOwe - weOwe`, which is exactly the payout expected by this party.

### No fines for honest parties

_No honest party will be fined regardless of the behaviour of the other party._

A party can be fined in three cases:

* They disappear and stop participating in the protocol. Honest parties do not
  disappear.
* They submit an improperly signed IOU. This is not possible because no party
  will continue processing an off-chain transaction with incorrect signature.
* They submit a close request, according to which they end up owing to the other
  party more than they have committed. This can only occur if they send more
  payments than their share allows, but an honest party must never do this.

### Reliable settlement for honest parties

_If both parties are honest, each of them will end up paying exactly as much
as they expect, even if some off-chain messages were not delivered._

* Values of `weOwe` stored in each party’s states are authoritative, that is
  they show the true total sum of payments made by the corresponding party.
  When resolving a conflict, the contract will respect the `iou - payout =
  weOwe` values submitted by both contracts, and thus use the true total
  sums in its balance computation.



## Further work

* Make optimisations for uni-directional channels.
* Allow parties to increase their shares as they go.
* Penalise parties by skewing the distribution in the end.
