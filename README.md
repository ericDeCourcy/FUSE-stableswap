> _Updated Oct 23 2021_

### Fuse Stable Swap

This is an implementation of the StableSwap algorithm for Fuse network. Curve and Saddle are both examples of StableSwap implementations on Mainnet Ethereum. Fuse Stable Swap is a fork of Saddle.

Fuse Stable Swap is currently deployed at [`0x3E192A2Eae22B3DB07a0039E10bCe29097E881B9`](https://explorer.fuse.io/address/0x3E192A2Eae22B3DB07a0039E10bCe29097E881B9/transactions) on Fuse network. It swaps between DAI <> USDC <> USDT with low slippage. The interface can be found at [ericdecourcy.github.io](https://ericdecourcy.github.io/). This pool is an instance of V3, which has rewards distributions and an adjustable total  LP cap.

### How to use the webpage

The first screen will connect metamask to the webpage.

The next screen will prompt you to approve tokens involved with the pool. If you're swapping between tokens, you'll need to **approve whatever token you're sending in to the swap**. If you're depositing tokens into the pool, you'll need to **approve any tokens you're depositing**. You'll need to **approve LP tokens for any withdraws**.

The final screen has different tabs in it, which allow for depositing, swapping, withdrawing, and claiming rewards. For withdrawals, there are different types to select. 

_Balanced Withdrawals_ withdraw coins in proportions equal to the pool's holdings. This is generally the easiest, you specify the amount of LP tokens you want to burn. _Imbalanced Withdrawals_ allow you specify how many of each token you'd like to get, and burns LPs accordingly to get you this amount. _Single Token Withdrawals_ allow you to specify a single token and amount of it to withdraw.

### Flashloans

By the way, the pool allows for flash loans. More info on this soon, but developers can look at `SwapFlashloanV3.sol` function `flashloan()` to get an idea for how to do this.

< TODO >

### Safety

The pool has not been audited. 

The pool is capped to a maximum number of LP tokens, currently 5000. If one attempts deposit funds which would put the totalSupply of LP tokens above 5000, the transaction will revert. Eventually the cap will be lifted, up to the maximum uint256 value.

Rewards contracts are separate from pool contracts, and do not affect pool contract state. This is by design to minimize any impacts from reward contract vulnerabilities. 

