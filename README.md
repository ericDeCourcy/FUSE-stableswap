# Fuse Stable Swap

### About
This is an implementation of the StableSwap algorithm for Fuse network. Curve and Saddle are both examples of StableSwap implementations on Mainnet Ethereum. Fuse Stable Swap is a fork of Saddle.

A StableSwap pool is a special type of AMM that allows for extremely low price impact when swapping between two assets which should have the same value. Thus, swapping between USDC and DAI should result in nearly 1:1 pricing (that is, getting 1 DAI for every 1 USDC provided). This only works for assets which should have the same value, like DAI and USDC which are both pegged to $1 USD.

StableSwap pools can be lucrative opportunities for investors, as they are not exposed to impermanent loss. This is again due to the fact that assets in a StableSwap pool are the same price. Investors can invest a basket of dollar-coins, for example, and know that their supplied liquidity is still safely in dollar-pegged stablecoin form.

Adding liquidity can be done with different amounts of each underlying collateral, rather than equal-value parts as is the case with Uniswap and it's forks. Liquidity providers can choose to provide liquidity entirely in one token, or in different amounts of all the tokens present in a pool. A StableSwap pool can have 3 to 5 different assets.

An additional feature of Fuse Stable Swap is that liquidity can be lent instantaneously for flashloans. More details on this to come, stay tuned!

### Security

Fuse stableswap was forked intentionally from an audited and battle-tested protocol, [Saddle Finance](https://saddle.finance/#/). The reward distribution functionality was forked from [Synthetix's `StakingRewards` contract](https://github.com/Synthetixio/synthetix/blob/master/contracts/StakingRewards.sol). Both codebases had minor modifications made to them to fit their usage on Fuse network.

There is currently no official bug bounty, nor has there been an audit for the protocol. If you find a bug, please contact ericDecourcy@protonmail.com.

### Risks

Smart contracts should never be considered completely safe, but the risk of smart contract bugs can be substantially reduced through auditing and having a responsible process for vulnerability disclosure. As stated in the "Security" section, there have been no audits for this protocol, and bug should be reported to ericDecourcy@protonmail.com. By forking battle-tested code and applying minimal changes, we hope to keep the code as safe as possible by lowering the chance of introducing new bugs.

One known issue which may affect users is **Significantly imbalanced pools**. In an ideal world, each Fuse StableSwap pool will have an equal amount of each pool token deposited. The ratios between assets in a pool determine each asset's price. When a pool has a severe imabalance, say 10%/10%/80% of tokens A,B, and C, respectively, the high supply of token C and relatively low supply of tokens A and B will cause token C to be offered for a lower price than tokens A and B. When users deposit large amounts of a single token, it can trigger arbitrage opportunities which result in losses for the liquidity providers. This is an unfortunate side effect of the self-regulation mechanism which exists in StableSwap pools. It happened when Saddle.finance launched, and can be read about [in this post from BeInCrypto](https://beincrypto.com/arbitraging-defi-whales-exploit-saddle-finance-launch-day/). **Solution:** Deposit tokens in mostly balanced ratios, and avoid depositing when the pools are significantly imbalanced.

Another known issue is **loss of peg for a single asset**. Unfortunately, when using tokens, the Fuse StableSwap protocol is exposed to any risks of those tokens. If a token like DAI loses it's peg, becoming worth significantly less than $1 on the open market, a StableSwap pool is likely to be completely drained of other tokens that are not DAI. The LP providers will be left holding LP tokens backed almost entirely by DAI. **Solution:** When depositing into a pool, ensure that you are comfortable with holding any of the underlying tokens in the pool.

### Ownership

The StableSwap protocol is currently managed by the address [`0x3c6c8D73CC8B06dc517BFcdF5C623a7b27146356`](https://explorer.fuse.io/address/0x3c6c8D73CC8B06dc517BFcdF5C623a7b27146356/transactions) on Fuse network. This account is owned by me, Eric DeCourcy (hello!). There are plans to move ownership of the protocol over to a multisig, and possibly to an on-chain governance process in the future. Stay tuned!

The admin account has the power to:
- Set both the swap fee and admin fee percentage
- Change the A parameter
- Change the LP cap
- Pause any pool (pausing disables all actions except withdrawing)
- Set up a new rewards scheme
- Change the admin account of the pool
- Change the admin account of the rewards contract

### Pool overview

Each pool offers users the ability to deposit tokens and swap between pool tokens. When depositing tokens, a user will recieve LP tokens. Fees from swaps will slowly increase the value of LP tokens over time.

LP tokens start being worth approximately 1 of any of the underlying pool tokens. For example, in a pool of USD coins, LP tokens will start being worth $1 USD. Over time, the value of the LP tokens will increase. 

Rewards can be set up by the pool's admin account. These rewards can be in the form of any ERC20 token, and will be automatically accrued for all LP's for a given pool. A rewards schedule is distributed over a fixed time to all LPs for a pool. The amount will accrue each block, and be distributed proportional to an LP's share of the total supply of LP tokens. 

Withdrawing from the pool will exchange LP tokens for the pool's underlying assets. This will burn LP tokens from the users account and send them underlying tokens out of the pool.

**The A parameter** controls the pricing mechanism of the pool. In simple terms, the A parameter dictates the degree to which prices will change as the pool becomes imbalanced. Generally, in an imbalanced pool, the tokens with smaller shares of the pool will be worth more to the pool, and the tokens with a large share of the pool will be worth less. As the A parameter gets larger, the price will change less as the pool becomes more imbalanced. A large A parameter helps to ensure healthy pricing regardless of how balanced the pool is, but also increases the risk of loss if a token in the pool cannot maintain its peg. The A parameter increases with the level of trust we can have for a pool.

**The LP cap** is a safety measure for limiting the risk of a pool. The LP cap prevents minting new LP tokens once the total supply hits the LP cap. This can be used to safely meter the growth of the pool, and limit financial losses in the unlikely event of a security incident. The LP cap can be unlimited - once it is set to `2^256 - 1` (the maximum value of a `uint` in solidity), there is effectively no LP cap, since LP token total supply cannot increase above this amount anyway due to limitations of the smart contract environment.

**Fees** There are two types of fees - there is the swap fee, and the admin fee. The swap fee is charged automatically on swaps. The admin fee is a percentage of the swap fee which goes to the admins. **When swapping, you will pay 0.05% per swap. Admins will recieve 10% of this, or 0.005% per swap** The remaining 0.045% will go towards LP token holders.

### Using Fuse Stable Swap
The interface can be found at [ericdecourcy.github.io](https://ericdecourcy.github.io/).

#### Current Pool
This dropdown menu allows you to select which pool to interact with.
- The **USD1 Pool** swaps between DAI <> USDC <> USDT.
- The **USD3 Pool** swaps between fUSD <> oneFUSE <> BUSD <> USDT. 

Note: the **USD2 Pool** has been shut down.

#### Deposit
To deposit in a pool, click the "Deposit" tab. Input the amounts of each token you would like to deposit, and click the button below. You may need to send multiple "approve" transactions before being able to deposit. By depositing, you'll get LP tokens and accrue interest and rewards.

#### Swaps
To swap, click the swap tab. You can input which token you're passing in for a swap and which token you want to recieve. Input how many tokens you're sending in. The app will calculate how many tokens you'll get back out. Click the button to approve and swap tokens.


#### Withdraw
There are different kinds of withdrawal: 
- **Balanced withdrawals** will withdraw tokens at an equal proportion to what is in the pool. So, if the pool contains 100 DAI and 10 USDC and 10 USDT, you will recieve tokens in a roughly 10:1:1 DAI:USDC:USDT ratio. 
- **Single Token withdrawals** can be selected by clicking the `Single Token Withdrawal` subtab. This will withdraw in the form of only a single token. You'll specify how many LP tokens to burn. LP tokens should typically be worth about $1.
- **Imbalanced withdrawals** are selected by clicking `Imbalanced Withdrawal` in the interface. These withdrawals will attempt to withdraw your desired amounts of each token, but will only succeed if your LP token balance is enough. Instead of inputting how many LP tokens to burn, you indicate how many tokens you'd like.

#### Rewards
Rewards are automatically accrued for liquidity providers. Currently there are no rewards; they can be set up by the pool admins. When rewards are set up, you can click the button in this tap to claim your rewards.

### Rewards

The rewards feature automatically accrued rewards every time there is a change to LP token balances. Within the LP token contract, every time there is a change in LP balances, including minting, burning, and transferring LP tokens, the reward rates per token are updated. This way, rewards accrue accurately. Reward rates for each reward program can be calculated following these formulas:

> (Reward Per Block) = (Reward tokens in schedule) / (blocks in schedule)

> (Reward Per LP token per block) = (Reward Per Block) / (LP token total supply)

> (Your reward per block) = (Reward per LP token per block) * (your LP tokens)

Note that while the reward tokens in a schedule will not change (unless the reward program is increased), the number of LP tokens in the total supply may fluctuate, so the reward per LP token will also fluctuate over time.

### Deployed pool addresses

Contract | Address (Fuse network)
---|---
USD1 Pool (`SwapFlashLoanV3.sol`) | [`0x3E192A2Eae22B3DB07a0039E10bCe29097E881B9`](https://explorer.fuse.io/address/0x3E192A2Eae22B3DB07a0039E10bCe29097E881B9/transactions)
USD1 LP Token | [`0x5c99419d48901EE803e6539c4155C2a024bEEDD3`](https://explorer.fuse.io/address/0x5c99419d48901EE803e6539c4155C2a024bEEDD3/transactions)
USD1 Rewards | [`0x48f25aA29691968D7C2fb2b0D0c02489D4ce3154`](https://explorer.fuse.io/address/0x48f25aA29691968D7C2fb2b0D0c02489D4ce3154/transactions)
USD1 SwapUtils | [`0x7BD853116626fC1E64BD9d3237F0262f0e0d276e`](https://explorer.fuse.io/address/0x7BD853116626fC1E64BD9d3237F0262f0e0d276e/transactions)
USD1 AmplificationUtils | [`0xBa97D236C566CA679b1C2E7DFCF056C47B4e5BB2`](https://explorer.fuse.io/address/0xBa97D236C566CA679b1C2E7DFCF056C47B4e5BB2/transactions)
USD2 Pool (`SwapFlashLoanV3.sol`) | [`0xECf95fFBa3e1Eb5f673606bC944fD093BB5D8EeD`](https://explorer.fuse.io/address/0xECf95fFBa3e1Eb5f673606bC944fD093BB5D8EeD/transactions)
USD2 LP Token | [`0x6A5Ea3652b88a9d066094216ACa18aC58eA216f5`](https://explorer.fuse.io/address/0x6A5Ea3652b88a9d066094216ACa18aC58eA216f5/transactions)
USD2 Rewards | [`0x9df200F086222084D86e252691d06C71480e440D`](https://explorer.fuse.io/address/0x9df200F086222084D86e252691d06C71480e440D/transactions)
USD2 SwapUtils | [`0x1f46fA48B08Ce95D43b16C46ffA4dFFd720Bd44b`](https://explorer.fuse.io/address/0x1f46fA48B08Ce95D43b16C46ffA4dFFd720Bd44b/transactions)
USD2 AmplificationUtils | [`0x8EcCb3D56c5b5CA9F092111060AB650a47916507`](https://explorer.fuse.io/address/0x8EcCb3D56c5b5CA9F092111060AB650a47916507/transactions)

### Contract versioning
In this repository, you can find multiple versions of the core contracts. These are suffixed with "V1", "V2", and "V3" to indicate which other contracts should be used with them. Many contracts are mostly unchanged across versions, but new versions are created for each core contract to avoid ambiguity. Whenever a contract is deployed, it should be deployed with libraries of the same version.

**The currently deployed pools are V3**. Below is a list of the differences between contract versions.
- V1: Forked from Saddle.finance
- V2: Introduces a rewards mechanism, which distributes rewards over time to LP token holders
- V3: Introduces a pool cap, which limits the maximum number of LP tokens which can exist at one time.

### Flashloans 

Flashloans are live on all deployed pools. Stay tuned for instructions on how to conduct flashloans. 

TODO

### Building on Fuse StableSwap

TODO

