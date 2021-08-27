### Fuse Stable Swap

This is an implementation of the StableSwap algorithm for Fuse network. Curve and Saddle are both examples of StableSwap implementations on Mainnet Ethereum. Fuse Stable Swap is a fork of Saddle.

### How to run the Demo

Currently (as of Aug 23, 2021) the demo interacts with a "Fake USD" pool. The pool contains fake versions of DAI, USDT, and USDC. **All of these tokens are worthless and freely mintable on Fuse network**. 

To run the demo, you will need:
* to have a private key for FUSE network. You can get this from metamask easily.
* to have enough FUSE to pay for gas fees. About 0.1 FUSE currently should be plenty. This should be in the account associated with your FUSE private key
* to have `npm` installed

Once you have these requirements, you should download this repo. 

Once the repo is saved somewhere, using the terminal, navigate to the directory containing `package.json`. Run `npm i --save-dev` to install the dependencies for the project.

Within the top level directory of the repo, create a file called `secrets.json`. This should be in the same directory as `hardhat.config.js`. 

Within `secrets.json`, put the following:

```
{
    "privateKey": "<your private key here>"
}
```

Replace `<your private key here>` with the private key for an account holding FUSE tokens. This can be obtained from metamask, or most other wallets. Be sure not to include a `0x` prefix, and be sure to keep the `"double quotes"` around your private key. And of course, don't disclose this to anyone, because it's the private key to your account.
 
Once this is done, run `npx hardhat run scripts/test-deployed-pool.js --network fuse`. This will take a while. It will send transactions from your account to interact with the deployed pool.