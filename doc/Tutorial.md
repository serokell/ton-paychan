# TON Payment Channel Tutorial

A payment channel is a contract that allows two parties to exchange payments
off-chain while the channel is open and get payouts at the end.

In this tutorial we will walk you through building the channel contract,
deploying it, making payments, and closing the channel.

## Get the sources and prerequisites

Start by cloning this repository to your computer.

In order to follow the tutorial, you will also need:

* A working installation of `func` to compile the contract.
* A working installation of `fift` to use the CLI of the contract.

(Make sure both of them are on your `$PATH`.)

* Also, some tool that allows submitting messages to the TON Blockchain
  is required, such as `lite-client`.

## Build the contract

Run:

* `make`

This will output the Fift Assembler code of the contract in `build/paychan.asm.fif`,
where you can review it, if you wish.

## Prepare

You can use the script located in `scripts/paychan` to perform off-chain payments
and to generate messages for the contract. This script can be called from any directory,
so you can just add it to your `$PATH` for convenience. Then test it by running without
any arguments:

```text
Usage:
  fift - s /path/to/ton-paychan/src/cli/Main.fif [ key | chan | payment ] ...

  Generate a new key pair:
    key gen <key name>
  (Writes keypair to `<key name>.sk` and `<key name>.pk`)

  Create a new payment channel:
    chan new <our key name> <our share> <their key name> <their share> <timeout> <fine amount> <extra fuel>
  (Writes joining request to `paychan.join`)

  Join a payment channel created by someone else:
    chan join <our key name> <their key name>
  (Reads joining request from `paychan.join`)

  Request a payment channel to close:
    chan close <channel address>

  Show information about a channel we created or joined:
    chan info <channel address>

  Send a state synchronisation message:
    chan sync <channel address>
  (Writes state sync message to `paychan.pay`)

  Make a payment through a payment channel:
    payment send <channel address> <amount>
  (Writes off-chain transaction to `paychan.pay`)

  Show infomation about a pending incoming payment:
    payment info
  (Reads off-chain transaction from `paychan.pay`)

  Receive a payment through a payment channel:
    payment receive <channel address>
  (Reads off-chain transaction from `paychan.pay`)
```

We will simulate two users by creating to directories for their respective files:

```text
$ mkdir alice
$ mkdir bob
```

and a helper function for running commands as these users:

```text
$ runalice () { (set -x; cd alice; "$@") }
$ runbob () { (set -x; cd bob; "$@") }
```

First let’s generate new keys and exchange their public parts:

```text
$ runalice paychan key gen alice
$ cp alice/alice.pk bob/
$ runbob paychan key gen bob
$ cp bob/bob.pk alice/
```

## Create a new payment channel

Now Alice creates a new channel in which she will have to commit GR$1
and Bob will commit 1GR$, inactivity timeout of 1 day and misbehaviour
fine of GR$0.5. The last argument is the extra amount that Alice would
like to send to the contract to cover its storage costs.

```text
$ runalice paychan chan new alice 2 bob 1 86400 0.5 0.1
Creating a new payment channel...
Loading secret key from file `alice.sk`
Loading public key from file `bob.pk`
Init-message written to file `init-message.boc`
Saving channel state to file `0-cd1993286f608c15723f35cc28952839b8381d0b53a5ca02e6e8eb286c3316bd.state`
Saving join request to file `paychan.join`
```

Let’s say the address into a shell variable:

```
$ addr='0-cd1993286f608c15723f35cc28952839b8381d0b53a5ca02e6e8eb286c3316bd'
```

and check its status:

```text
$ runalice paychan chan info $addr
Keys: alice - bob
Shares: GR$2. - GR$1.
Timeout: 86400 (fine: GR$0.5)

Balance: GR$0. (GR$0. - GR$0.)
Missing: GR$0.
```

Now Alice should submit the `init-message.boc` file to the TON Blockchain
through her wallet. The standard Wallet contract that comes with the
TON distribution will work, but `wallet.fif` cannot be used to sign this
init message, since it contains a StateInit, which `wallet.fif` does not
support. However, you can use `scripts/wallet-4-pc.fif` instead:

```text
$ fift -s ./scripts/wallet-4-pc.fif` alice-wallet 12 alice/init-message.boc
[...]
$ lite-client -c "sendfile wallet-query.boc"
[...]
```

Lastly, Alice shares a join request with Bob. The request carries all the
necessary information about the contract, such as its configuration and
address.

```text
$ runalice mv paychan.join ../bob/
```

## Join a channel

After bob receives a request from Alice, he can use it to join the channel:

```text
$ runbob paychan chan join bob alice
Joining a channel...
Loading secret key from file `bob.sk`
Loading public key from file `alice.pk`
Loading join request from file `paychan.join`
Saved join message for smartcontract to join-message.boc
Saving channel state to file `0-cd1993286f608c15723f35cc28952839b8381d0b53a5ca02e6e8eb286c3316bd.state`
```

## Send payments

Alice sends three payments to Bob through the channel:

```text
$ runalice paychan payment send $addr 0.1
Loading secret key from file `alice.sk`
Payment: (channel = 0-cd1993286f608c15723f35cc28952839b8381d0b53a5ca02e6e8eb286c3316bd)
  Amount = GR$0.1
  New balance = GR$-0.1
Outgoing ->
Saving payment to file `paychan.pay`

$ runalice mv paychan.pay ../bob/1.pay
```

```text
$ runalice paychan chan info $addr
Keys: alice - bob
Shares: GR$2. - GR$1.
Timeout: 86400 (fine: GR$0.5)

Balance: GR$-0.1 (GR$0.1 - GR$0.)
Missing: GR$0.
```

```text
$ runalice paychan payment send $addr 0.2
Loading secret key from file `alice.sk`
Payment: (channel = 0-cd1993286f608c15723f35cc28952839b8381d0b53a5ca02e6e8eb286c3316bd)
  Amount = GR$0.2
  New balance = GR$-0.3
Outgoing ->
Saving payment to file `paychan.pay`

$ runalice mv paychan.pay ../bob/2.pay
```

```text
$ runalice paychan payment send $addr 0.3
Loading secret key from file `alice.sk`
Payment: (channel = 0-cd1993286f608c15723f35cc28952839b8381d0b53a5ca02e6e8eb286c3316bd)
  Amount = GR$0.3
  New balance = GR$-0.6
Outgoing ->
Saving payment to file `paychan.pay`

$ runalice mv paychan.pay ../bob/3.pay
```

```text
$ runalice paychan chan info $addr
Keys: alice - bob
Shares: GR$2. - GR$1.
Timeout: 86400 (fine: GR$0.5)

Balance: GR$-0.6 (GR$0.6 - GR$0.)
Missing: GR$0.
```

## Receiving a payment

Bob receives the first payment:

```text
$ runbob mv 1.pay paychan.pay

$ runbob paychan payment info
Loading payment from file `paychan.pay`
Payment: (channel = 0-cd1993286f608c15723f35cc28952839b8381d0b53a5ca02e6e8eb286c3316bd)
  Amount = GR$0.1
  New balance = GR$+0.1
<- Incoming

$ runbob paychan payment receive $addr
Loading public key from file `alice.pk`
Loading payment from file `paychan.pay`
Payment received. Amount = GR$0.1
```

```text
$ runbob paychan chan info $addr
Keys: bob - alice
Shares: GR$1. - GR$2.
Timeout: 86400 (fine: GR$0.5)

Balance: GR$+0.1 (GR$0. - GR$0.1)
Missing: GR$0.
```

## Out of order payments

It happens so that payment number three arrives next:

```text
$ runbob mv 3.pay paychan.pay

$ runbob paychan payment receive $addr
Loading public key from file `alice.pk`
Loading payment from file `paychan.pay`
Note: some incoming payments are missing.
Payment received. Amount = GR$0.3
```

Note that the CLI detects that a payment is missing and warns the user
so that they can request it again, if they need to, although it does
not affect the functionality of the channel in any way.

The missing amount is recorded in the local state for convenience of the user:

```text
$ runbob paychan chan info $addr
Keys: bob - alice
Shares: GR$1. - GR$2.
Timeout: 86400 (fine: GR$0.5)

Balance: GR$+0.6 (GR$0. - GR$0.6)
Missing: GR$0.2
```

Now the second payment arrives:

```text
$ runbob mv 2.pay paychan.pay

$ runbob paychan payment $addr
Loading public key from file `alice.pk`
Loading payment from file `paychan.pay`
Note: this appears to be a previously missing payment.
Payment received. Amount = GR$0.2
```

Note that the CLI warns the user that this is a previously missing payment
and the missing amount in local state is back to zero:

```text
$ runbob paychan chan info $addr
Keys: bob - alice
Shares: GR$1. - GR$2.
Timeout: 86400 (fine: GR$0.5)

Balance: GR$+0.6 (GR$0. - GR$0.6)
Missing: GR$0.
```

## Missing payments

This time Bob sends two payments to Alice:

```text
$ runbob paychan payment send $addr 0.15
Loading secret key from file `bob.sk`
Payment: (channel = 0-cd1993286f608c15723f35cc28952839b8381d0b53a5ca02e6e8eb286c3316bd)
  Amount = GR$0.15
  New balance = GR$+0.45
Outgoing ->
Saving payment to file `paychan.pay`

$ runbob mv paychan.pay ../alice/1.pay
```

```text
$ runbob paychan payment send $addr 0.25
Loading secret key from file `bob.sk`
Payment: (channel = 0-cd1993286f608c15723f35cc28952839b8381d0b53a5ca02e6e8eb286c3316bd)
  Amount = GR$0.25
  New balance = GR$+0.2
Outgoing ->
Saving payment to file `paychan.pay`


$ runbob mv paychan.pay ../alice/2.pay
```

Alice receives the first one:

```text
$ runalice mv 1.pay paychan.pay

$ runalice paychan payment receive $addr
Loading public key from file `bob.pk`
Loading payment from file `paychan.pay`
Payment received. Amount = GR$0.15
```

Unfortunately, Bob’s second payment is gone.

```text
$ runalice rm 2.pay
```

Alice sends a payment to Bob:

```text
$ runalice paychan payment send $addr 0.15
Loading secret key from file `alice.sk`
Payment: (channel = 0-cd1993286f608c15723f35cc28952839b8381d0b53a5ca02e6e8eb286c3316bd)
  Amount = GR$0.15
  New balance = GR$-0.6
Outgoing ->
Saving payment to file `paychan.pay`
```

And Bob receives it right away:

```text
$ runbob mv paychan.pay ../bob/

$ runbob paychan payment receive 0-cd1993286f608c15723f35cc28952839b8381d0b53a5ca02e6e8eb286c3316bd
Loading public key from file `alice.pk`
Loading payment from file `paychan.pay`
Note: the other party is missing some of our payments.
Payment received. Amount = GR$0.15
```

Note that the CLI warns him that Alice is missing his latest payment
so he might decide to resend it. Again, this is purely optional and will
not affect the final payouts when the contract is closed, as long as
Bob participates in the closing procedure rather than disappears.

## State sync

Before closing the channel it is recommended that Alice and Bob synchronise
their states, just to be safe, in case one of them suddenly disappears.
Also, this will help them save a little on gas costs as the channel settlement
will go through a simpler code path in the contract.

```text
$ runalice paychan chan sync $addr
Loading secret key from file `alice.sk`
State sync message will be formatted as a payment with amount = 0.
Saving payment to file `paychan.pay`

$ runalice mv paychan.pay ../bob/

$ runbob paychan payment receive $addr
Loading public key from file `alice.pk`
Loading payment from file `paychan.pay`
Note: the other party is missing some of our payments.
This was a state sync message. State synchronised.
```

```text
$ runbob paychan chan sync $addr
Loading secret key from file `bob.sk`
State sync message will be formatted as a payment with amount = 0.
Saving payment to file `paychan.pay`

$ runbob mv paychan.pay ../alice/

$ runalice paychan payment receive 0-cd1993286f608c15723f35cc28952839b8381d0b53a5ca02e6e8eb286c3316bd
Loading public key from file `bob.pk`
Loading payment from file `paychan.pay`
Note: some incoming payments are missing.
This was a state sync message. State synchronised.
```

Note that Alice now knows that there was a missing payment, but her
state is fully up-to-date.

```
$ runalice paychan chan info $addr
Keys: alice - bob
Shares: GR$2. - GR$1.
Timeout: 86400 (fine: GR$0.5)

Balance: GR$-0.35 (GR$0.75 - GR$0.4)
Missing: GR$0.25
```

## Close the channel

```text
$ runalice paychan chan close $addr
Loading secret key from file `alice.sk`
Saved close message for smartcontract to close-message.boc
```

```text
$ runbob paychan chan close $addr
Loading secret key from file `bob.sk`
Saved close message for smartcontract to close-message.boc
```

Now all that remains is for the two parties to sign their close messages
and submit them to the TON Blockchain.
