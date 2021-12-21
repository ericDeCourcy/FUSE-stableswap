pragma solidity 0.6.12;

import "./contracts-v3_4/token/ERC20/IERC20.sol";
import "./interfaces/ISwapFlashLoanV3.sol";
import "./contracts-v3_4/math/SafeMath.sol";

contract RoutableSwapWrapper {
    using SafeMath for uint;

    address public underlyingPool;

    constructor(address[] memory _tokens, address _underlyingPool) public
    {
        // approve each token for the pool to transfer
        for(uint256 i= 0; i < _tokens.length; i++)
        {
            IERC20(_tokens[i]).approve(underlyingPool, uint256(-1));
        }          

        underlyingPool = _underlyingPool;
    }

    // function swap
    // TODO: make sure name matches the uniswap pool calls
    /**
     * @dev this assumes that the tokens for the swap are already present in this contract.
     * @dev Only call this function immediately after sending tokens to this contract
     */
    // TODO: is there any problem with sending all the tokens this contract posesses? 
    //      only problem i can see is if there's some requirement that the number of tokens isn't greater than x

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,    // We have to keep "amountIn" because if we allow the contract to send
                            // balance or some other amount, it might revert when a later step expects
                            // a certain amount of tokens.
        address to
    )   // TODO do we need a min amount out?
    external 
    {
        // get token indices from swap contract 
        // Note: this will revert in the SwapFlashLoanV3 contract if token index doesn't exist
        uint8 indexIn = ISwapFlashLoanV3(underlyingPool).getTokenIndex(tokenIn);
        uint8 indexOut = ISwapFlashLoanV3(underlyingPool).getTokenIndex(tokenOut);

        // to get accurate swap outputs, don't allow naive token sends to change the output
        // send the 'to' address the amount that the output balance increased. To do this, take the
        // balance before the swap occurs and subtract it out
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));

        // we auto-fill 1 and "now" for the minDy and for the deadline
        ISwapFlashLoanV3(underlyingPool).swap(indexIn, indexOut, amountIn, 1, now);

        IERC20(tokenOut).transfer(to, (IERC20(tokenOut).balanceOf(address(this)).sub(balanceBefore)));
    }

    // function getAmountOut
    // TODO:should name match uniswap router or nah?
    /**
     * @dev For calling into the swap contract, this needs to use token indices
     *      However for better interoperability we should have an input here be the token addresses
     */
    function getAmountOut(
         address tokenIn, 
         address tokenOut,
         uint256 amountIn
    ) 
    external view returns(uint256)
    {
        // get token indices from swap contract 
        // Note: this will revert in the SwapFlashLoanV3 contract if token index doesn't exist
        uint8 indexIn = ISwapFlashLoanV3(underlyingPool).getTokenIndex(tokenIn);
        uint8 indexOut = ISwapFlashLoanV3(underlyingPool).getTokenIndex(tokenOut);

        return ISwapFlashLoanV3(underlyingPool).calculateSwap(indexIn, indexOut, amountIn);
    }

    /**
     * @dev Approximates input until convergence. Start at 1:1 ratio, then overshoot the difference by 10%
     * For example, say we want 100 tokens out. We find 100 tokens in nets 95.23 tokens out. 
     * 100 tokens desired/ 95.23 gotten = 105% increase
     * 105% increase apparent ---> 100% + 5% ---> increase the 5% part by 10%, so 5.5%
     * increase input to (100 * (100 + 5.5)%) = 105.5 and try again
     */
    function getAmountIn(
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    )
    external view returns(uint256)
    {
        uint8 indexIn = ISwapFlashLoanV3(underlyingPool).getTokenIndex(tokenIn);
        uint8 indexOut = ISwapFlashLoanV3(underlyingPool).getTokenIndex(tokenOut);

        // TODO: make sure this won't get fucked in lots of diff cases
        uint256 initialAmountIn = amountIn * (10**IERC20(tokenOut).decimals()) / (10**IERC20(tokenIn).decimals());
        uint256 lastAmountIn = initialAmountIn;

        uint256 amountOutCalculated = ISwapFlashLoanV3(underlyingPool).calculateSwap(indexIn, indexOut, initialAmountIn);

        // TODO: require that amountOut is lower than 2^255? or 254? That way, if is subs it won't overflow an int256 calculation
        while(amountOutCalculated != amountOut)
        {
            // get diff between calculated and desired amount
            // TODO: signed math library?
            int256 diff = amountOut - amountOutCalculated; 

            // calculate percentage to scale the input for next round
            if(diff > 0) // if amountOut is higher than the amountOutCalculated
            {
                // newAmountIn = (((diff * 1.1) + amountOutCalculated) / amountOutCalculated) * lastAmountIn;
            }
            else if(diff < 0) // shouldn't need an "if" here
            {
                
            }


            else{ revert("RoutableSwapWrapper.getAmountIn: Something mathy is broken"); } //this should never happen

            // calculate swap with new scaled input

            // if what is just calculated equals the very last calculation, add or sub 1 

        }
    }

}