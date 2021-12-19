// this contract wraps the fuseSwap router to condense calls involving multiple trades into 1
// the fuseswap wrapper routes trades across different pools to conduct swaps between tokens which may not share a pool
// this contract does similarly, except that it may make chains of fuseSwap swaps AND swaps through Fuse stable swap
pragma solidity 0.6.12;

contract StableSwapRouterWrapperV3 { 

    address public constant fuseSwapRouter = 0xFB76e9E7d88E308aB530330eD90e84a952570319;
    uint256 public constant MAX_UINT = -1;

	/**
	 * @dev This function does a series of smaller "exact-to-tokens" trades. When the overall trade is "tokens-to-exact", we do a bunch of "tokens-to-exact" trades
	 */
	function swapExactTokensForTokens(
		uint amountIn,
		uint amountOutMin,
		address[] calldata path,
		uint32 isStableSwap,	//from LSB to MSB, a "1" bit indicates that that swap step in the path should go through stableswap
		address to,		//TODO: should we restrict this to being this contract's address? Seems that tokens will get sent to this address during the swap intermediate steps
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
		
		uint pathCount = 1; // tells us highest step of the trade we have conducted
		// should have values of 1-32 indicating which step of the trade we are on
		// 1 means the input token - corresponds with LSB of `isStableSwap` which should always be 0
		// 2 means the first token it is swapped to - corresponds with 2nd-most-LSB of `isStableSwap`
		// 32 corresponds with MSB of `isStableSwap`
		uint nextStableSwap = 0;	//tells us index of the next stableSwap needed
		// starts at 0 to indicate unknown, otherwise 2-32 to indicate that a stableswap will be needed to get to the token at that "step" of the trade
		// remember that "step 1" is simply getting the tokens in from the user, steps 2-32 are swaps 
		
		uint256[] memory slicedPath;

		// loop, conducting chunks of the FSS swaps or fuseswap swaps as needed
		while(pathCount < path.length)	//once pathcount hits path.length, it will have the value of the last index plus one. 
		{
			// loop to find the next stableswap, setting `nextStableSwap` and exiting
			// TODO: replace with "_findNextStableSwap(pathCount, path[])"
			nextStableSwap = _findNextStableSwap(pathCount, pathLength, isStableSwap);
			
			// TODO: this all can be skipped if the next swap is a stableswap already
			// slice the path array to call the uniswap router
				// TODO: we may have to use a storage array if we are not allowed to create a new array for each while loop iteration this way
			uint256[] memory slicedPath = _getSlicedPath(path, pathCount, nextStableSwap);
			
			// then, perform a fuseswap-routed trade for that path slice
			if(path[pathCount-1] != ETH_ADDRESS)	//input token isn't ETH...
			{
				
				// if input token isn't approved
				if(IERC20(path[pathCount-1]).allowance(address(this), fuseSwapRouter) < IERC20(path[pathCount-1]).balanceOf(address(this))) //TODO: can we assume we will be swapping the whole balance of this token? 
				{
					TransferHelper.safeApprove(path[pathCount-1], fuseSwapRouter, MAX_UINT);
				}
				
				// perform swap
				if(path[nextStableSwap-1] != ETH_ADDRESS)	//output token isn't eth either
				{
					// use ExactTokensToTokens
					FuseSwapRouter.swapExactTokensForTokens(amountIn, amountOutMin, slicedPath, to deadline);	//TODO is "to" needed here - might not be and might be a way to get tokens sent to the wrong spot
				}
				else //output token IS ETH, but input still isn't
				{
					// use ExactTokensToETH
					TODO swap with fuseswap router
				}
			}
			else if(path[pathCount-1] == ETH_ADDRESS)	//when input token IS ETH...
			{
				// no approval needed :)

				// perform swap
				if(path[nextStableSwap-1] != ETH_ADDRESS)	//output token isn't ETH
				{
					// use ExactETHToTokens
					TODO swap with fuseswap
				}
				else // rare case!!! output and input are ETH, they're the same coin! We simply do nothing, and act like the swap happened
				{
					// do nothing
				}
			}

			// then increment pathCount to nextStableSwap-1
			pathCount = nextStableSwap-1;
			
			
			// then, if a stableswap is up next, conduct a stable swap
			// TODO: since we're only conducting one stableswap at a time, make sure this works with diff combos of swaps
			//	F = fuseswap, S = Stableswap
			// FFSS
			// FSS
			// FSSFFSS
			// FFFSSFFFSS
			// FSSFFFS
			// FFF
			if(nextStableSwap <= path.length)	// indicates that there is still a stableswap in bounds
												// nextStableSwap can equal path.length, representing that it is the last swap in the series
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

	function _findNextStableSwap(uint256 pathCount, uint256 pathLength, uint32 isStableSwap) internal returns (uint256 nextStableSwap)
	{
		for(uint256 i = pathCount; i <= pathLength; i++) // on first round, i = 1
			{
				if(i == pathLength)	//indicates we are done - no more stableswapping
				{
					return pathLength+1;	// TODO: ensure this will work
				}
				
				if(_getBitAt(isStableSwap, i+1) == 1)	// this means we've found a stableSwap needed to get to i+1
				{
					return i+1;
				}
			}
		}

		// since i++ and i==path.length closes the loop, we don't need anything here
		// TODO: ensure that there's no way for pathCount to exceed path.length initially
	}

	/**
	 * @dev returns a path including pathCount going up to nextStableSwap-1
	 */
	function _getSlicedPath(address[] memory path, uint256 pathCount, uint256 nextStableSwap) returns (uint256[] memory slicedPath)
	{
		// TODO: can we even return a dynamically sized memory array? Example of doing so: https://www.geeksforgeeks.org/dynamic-arrays-and-its-operations-in-solidity/
		
		
		uint256[] memory slicedPath = new uint256[](nextStableSwap - pathCount);	// path includes "pathCount" token - so if next stableswap is on step 5, and pathCount is 2, we must include steps 2,3,4. (5-2 = 3)

		for(uint256 i = 0; i < slicedPath.length; i++) // will hit each index in slicedPath
		{
			slicedPath[i] = path[pathCount-1+i];	//when pathCount is 2, it will represent path[1].
													//when i = slicedPath.length-1, we will be accessing path[pathCount + slicedPath.length - 2], or path[nextStableSwap - 2]
		}
		
		return slicedPath;
	}

}