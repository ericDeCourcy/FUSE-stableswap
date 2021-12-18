// this contract wraps the fuseSwap router to condense calls involving multiple trades into 1
// the fuseswap wrapper routes trades across different pools to conduct swaps between tokens which may not share a pool
// this contract does similarly, except that it may make chains of fuseSwap swaps AND swaps through Fuse stable swap
pragma solidity 0.6.12;

contract StableSwapRouterWrapperV3 { 

    address public constant fuseSwapRouter = 0xFB76e9E7d88E308aB530330eD90e84a952570319;
    uint256 public constant MAX_UINT = -1;

	function swapExactTokensForTokens(
		uint amountIn,
		uint amountOutMin,
		address[] calldata path,
		uint32 calldata isStableSwap,	//from LSB to MSB, a "1" bit indicates that that swap step in the path should go through stableswap
		address to,
		uint deadline
    ) external returns(uint[] memory amounts) // TODO: do we want this to be virtual override? (I don't think it needs to be override)
	{
		require(path.length < 33, "Cannot conduct more than 32 swaps at a time");	//this is due to the fact that isStableSwap is a bytes32
        // TODO: does this get checked already? Is there some other limit to swaps which is less than 32?

		require(path.length > 1, "Swap paths must have length of 2 or greater");

        require(now < deadline, "Deadline has passed"); // is this needed? Deadline checks are present in FuseSwap router and stableswap swaps. So, we'll be checking them anyway
        // TODO: determine if we can remove this ^^^

        // transfer in tokens for the swaps
		TransferHelper.safeTransfer(path[0], address(this), amountIn);
		
		uint pathCount = 0; // tells us what step of the path we have examined already
		uint nextStableSwap = 0;	//tells us index of the next stableSwap needed
		
		// loop, conducting chunks of the FSS swaps or fuseswap swaps as needed
		while(pathCount < path.length)	//once pathcount hits path.length, it will have the value of the last index plus one. 
		{
			
			// loop to find the next stableswap
			for(i = pathCount; i <= path.length; i++) // on first round, i = 0
			{
				if(i == path.length)	//indicates we are done - no more stableswapping
				{
					nextStableSwap = 100;	//or some dummy var...?
				}
				
				// determine if the step to the next element in path will go through FSS
				// check the bit at i+1 of isStableSwap
				// if bit is 0 (not stableSwap), continue looping
				// otherwise exit the loop
				if(isStableSwap[i+1] == 1)	// this means we've found a stableSwap needed to get to i+1
				{
					nextStableSwap = i+1;
				}
			}
			
			// if nextStableSwap has a valid value, conduct a uniswap router swap to get to right before it
			if(nextStableSwap != 100)
			{
				// slice the path array to call the uniswap router
				// perform the route from pathCount (-1 ???) to (nextStableSwap-1) via the uniswap router
                if(IERC20(path[pathCount]).allowance(address(this), fuseSwapRouter) < IERC20(path[pathCount]).balanceOf(address(this))) //TODO: can we assume we will be swapping the whole balance of this token? 
                {
                    TransferHelper.safeApprove(path[pathCount], fuseSwapRouter, MAX_UINT);
                }
                
				TODO: swap using fuseswap router
				
				// then increment pathCount to nextStableSwap-1
				pathCount = nextStableSwap-1;
			}
			else	// this assumes nextStableSwap has value 100 and is therefore indicating no more stableswaps
			{
                TODO: approve tokens for transfer to fuseSwap router
				TODO: call fuseSwapRouter and perform all remaining swaps
				
				pathCount = path.length;		// this is done so we can exit the main loop
			}
			
			// then, if a stableswap is up next, conduct a stable swap
			// TODO: since we're only conducting one stableswap at a time, make sure this works with diff combos of swaps
			//	F = fuseswap, S = Stableswap
			// FFSS
			// FSS
			// FSSFFSS
			// FFFSSFFFSS
			// FSSFFFS
			// FFF
			if(nextStableSwap == pathCount+1)
			{
				TODO: determine which stableswap pool to call
                TODO: approve stableswap to transfer tokens
				TODO: call to conduct a stableSwap	
				
				pathCount++;
			}
		}
		
		TODO: check token amount is okay...?
		TODO: transfer token to user
		
		
	}
	
	
	function swapTokensForExactTokens
	
	function swapTokensForExactETH
	
	function swapExactTokensForETH
	
	function swapETHForExactTokens
	
	///? WTF there is no "swapExactETHForTokens"..?
}