# Fuse Stable Swap

### About
This is an implementation of the StableSwap algorithm for Fuse network. Curve and Saddle are both examples of StableSwap implementations on Mainnet Ethereum. Fuse Stable Swap is a fork of Saddle.

A StableSwap pool is a special type of AMM that allows for extremely low price impact when swapping between two assets which should have the same value. Thus, swapping between USDC and DAI should result in nearly 1:1 pricing (that is, getting 1 DAI for every 1 USDC provided). This only works for assets which should have the same value, like DAI and USDC which are both pegged to $1 USD.

StableSwap pools can be lucrative opportunities for investors, as they are not exposed to impermanent loss. This is again due to the fact that assets in a StableSwap pool are the same price. Investors can invest a basket of dollar-coins, for example, and know that their supplied liquidity is still safely in dollar-pegged stablecoin form.

Adding liquidity can be done with different amounts of each underlying collateral, rather than equal-value parts as is the case with Uniswap and it's forks. Liquidity providers can choose to provide liquidity entirely in one token, or in different amounts of all the tokens present in a pool. A StableSwap pool can have 3 to 5 different assets.

An additional feature of Fuse Stable Swap is that liquidity can be lent instantaneously for flashloans. More details on this to come, stay tuned!


### Using Fuse Stable Swap
The interface can be found at [ericdecourcy.github.io](https://ericdecourcy.github.io/).

Fuse Stable Swap currently (as of November 28 2021) has two pools. 
- The **USD1 Pool** swaps between DAI <> USDC <> USDT. It is deployed on Fuse network at [`0x3E192A2Eae22B3DB07a0039E10bCe29097E881B9`](https://explorer.fuse.io/address/0x3E192A2Eae22B3DB07a0039E10bCe29097E881B9/transactions).
- The **USD2 Pool** swaps between DAI <> fUSD <> USDT. It is deployed on Fuse network at [`0xECf95fFBa3e1Eb5f673606bC944fD093BB5D8EeD`](https://explorer.fuse.io/address/0xECf95fFBa3e1Eb5f673606bC944fD093BB5D8EeD/transactions).

To switch between pools, choose the pool you want from the dropdown menu labeled "Current Pool" in the interface.

**Swaps** are conducted by picking the token to swap from, and the token to swap to. You'll need to approve the input token, which you will be prompted to do from the interface if you have not done so already. Swaps are highly efficient and net better prices than uniswap and its forks. Prices should be close to 1:1. These can be found in the `Swap` tab of the interface.

**Deposits** are conducted in the `Deposit` tab of the interface. You can deposit `0` or more of each token into the pool you have selected. If depositing any number other than `0` for a given token, you will need to approve each token before depositing, which you will be prompted to do from the interface if you have not done so already.

**Withdrawals** are conducted from the `Withdraw` tab of the interface. To conduct any withdrawal, you will need to approve the pool's LP token before withdrawing if you have not done so already. Read about the different types of withdrawal below:
- "Balanced" withdrawals can be selected by clicking on the `Balanced Withdrawal` subtab in the interface. This will withdraw tokens at an equal proportion to what is in the pool. So, if the pool contains 100 DAI and 10 USDC and 10 USDT, you will recieve tokens in a roughly 10:1:1 DAI:USDC:USDT ratio. 
- "Single Token" withdrawals can be selected by clicking the `Single Token Withdrawal` subtab. This will withdraw in the form of only a single token. For both balanced withdrawals and Single Token withdrawals, you specify the number of LP tokens to exchange for your withdrawn tokens. 
- "Imbalanced" withdrawals are selected by clicking `Imbalanced Withdrawal` in the interface. These withdrawals will attempt to withdraw your desired amounts of each token, but will only succeed if your LP token balance is enough.

**Rewards** are automatically accrued for liquidity providers. Currently there are no rewards; they can be set up by the pool admins.

### Contract versioning
In this repository, you can find multiple versions of the core contracts. These are suffixed with "V1", "V2", and "V3" to indicate which other contracts should be used with them. Many contracts are mostly unchanged across versions, but new versions are created for each core contract to avoid ambiguity. Whenever a contract is deployed, it should be deployed with libraries of the same version.

**The currently deployed pools are V3**. Below is a list of the differences between contract versions.
- V1: Forked from Saddle.finance
- V2: Introduces a rewards mechanism, which distributes rewards over time to LP token holders
- V3: Introduces a pool cap, which limits the maximum number of LP tokens which can exist at one time.
