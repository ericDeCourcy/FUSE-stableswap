pragma solidity 0.6.12;
    
interface IRoutableSwapWrapper {
 
    function swap(address tokenIn, address tokenOut, uint256 amountIn, address to) external;

    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn) external view returns(uint256);
}  