<!--
   - SPDX-FileCopyrightText: 2019 Serokell <https://serokell.io>
   -
   - SPDX-License-Identifier: MPL-2.0
   -->

# TON Payment Channels

_Fast and cheap off-chain micro-transactions for the Telegram Open Network._


A payment channel allows two parties to send funds to each other over a period
of time using fast and cheap micro-transactions. The micro-transactions happen
off-chain, however they are guaranteed by funds locked on-chain and
do not require the parties to trust each other.

### How it works

* The payment channel is preconfigured with the addresses of the two parties
  involved and deployed.
* Both parties contribute their shares by sending them to the contract.
* All further transactions happen off-chain by exchanging signed messages
  in a special format that facilitates keeping track of liabilities.
* After all micro-transactions have been performed, the two parties communicate
  the results to the contract and it redistributes the funds accordingly.

### Guarantees

* If one of the parties disappears and stops communicating according to the
  protocol, the locked funds are released after a predetermined timeout.
* If one of the parties behaves dishonestly, the other party can terminate
  the channel and get the funds redistributed according to the last known
  good state before the other party started behaving dishonestly.
* Optionally, misbehaviour (disappearing or being actively dishonest)
  can be penalised by incurring a fine on the misbehaving party.


### Specification

[Payment-channel.md](doc/Payment-channel.md)


## Use

### Configuring, building, and deploying the contract

TODO

### Initialising the payment channel

TODO

### Sending and receiving micro-transactions

TODO

### Closing the payment channel

TODO

### Terminating the payment channel due to misbehaviour

TODO


## About Serokell

This repository is maintained and funded with ❤️ by [Serokell](https://serokell.io/).
The names and logo for Serokell are trademark of Serokell OÜ.

We love open source software! See [our other projects](https://serokell.io/community?utm_source=github) or [hire us](https://serokell.io/hire-us?utm_source=github) to design, develop and grow your idea!
