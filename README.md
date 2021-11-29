### Fuse Stable Swap

This is an implementation of the StableSwap algorithm for Fuse network. Curve and Saddle are both examples of StableSwap implementations on Mainnet Ethereum. Fuse Stable Swap is a fork of Saddle.

Fuse Stable Swap is currently (as of October 23 2021) deployed at [`0x3E192A2Eae22B3DB07a0039E10bCe29097E881B9`](https://explorer.fuse.io/address/0x3E192A2Eae22B3DB07a0039E10bCe29097E881B9/transactions) on Fuse network. It swaps between DAI <> USDC <> USDT with low slippage. The interface can be found at [ericdecourcy.github.io](https://ericdecourcy.github.io/).

**The currently deployed pools are V3**. All of the involved contracts have been suffixed with "V3" in their filenames. 
- V1: Forked from Saddle.finance
- V2: Introduces a rewards mechanism, which distributes rewards over time to LP token holders
- V3: Introduces a pool cap, which limits the maximum number of LP tokens which can exist at one time.
