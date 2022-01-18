// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import "./V3/SwapFlashLoanV3.sol";

contract RouteHandler{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    modifier deadlineCheck(uint256 deadline) {
        require(block.timestamp <= deadline, "Deadline not met");
        _;
    }

    function calculateAndCheckSwapRoute(address[] memory poolPath, address[] memory tokenPath, uint256 dx) public view returns (uint256[] memory){
        // TODO: make this a function that returns uint256[] dys, which is the return values of each swap
        // uint256 dy = dx;
        uint256[] memory dys = new uint256[](tokenPath.length);
        dys[0] = dx;

        require(poolPath.length == tokenPath.length - 1, "RouteHandler.sol: poolPath.length != tokenPath.length - 1");
        for(uint8 i=1; i<tokenPath.length; i++){
            address pool = poolPath[i-1];
            uint8 tokenA; uint8 tokenB;
            (tokenA, tokenB) = getTokensIndicesFromPool(pool, tokenPath[i-1], tokenPath[i]);
            dys[i] = SwapFlashLoanV3(pool).calculateSwap(tokenA, tokenB, dys[i-1]);
        }
        // require(dys[dys.length - 1] >= minDy, "RouteHandler.sol: Inefficient trade");
        return dys;
    }

    function getTokensIndicesFromPool(address pool, address tokenA, address tokenB) public view returns (uint8 indexA, uint8 indexB) {
        return (
            SwapFlashLoanV3(pool).getTokenIndex(tokenA),
            SwapFlashLoanV3(pool).getTokenIndex(tokenB)
        );
    }

    function swapWithRoute(address[] memory poolPath, address[] memory tokenPath, uint256 dx, uint256 minDy, uint256 deadline) external deadlineCheck(deadline) {
        // check allowance of tokenPath[0] and transfer to `this`
        {
            IERC20 tokenA = IERC20(tokenPath[0]);
            require(
                dx <= tokenA.balanceOf(msg.sender),
                "Cannot swap more than you own"
            );

            uint256 beforeBalance = tokenA.balanceOf(address(this));
            tokenA.transferFrom(msg.sender, address(this), dx);

            // Use the actual transferred amount for AMM math
            dx = tokenA.balanceOf(address(this)).sub(beforeBalance);
        }

        uint256[] memory expectedDys = calculateAndCheckSwapRoute(poolPath, tokenPath, dx);
        require(expectedDys[expectedDys.length - 1] >= minDy, "Swap didn't result in min tokens");

        for(uint8 i=1; i<tokenPath.length; i++){
            address pool = poolPath[i-1];
            // approve tokens to the pool
            {
                IERC20 tokenA = IERC20(tokenPath[i-1]);
                tokenA.approve(poolPath[i-1], expectedDys[i-1]);
            }
            uint8 tokenAIndex; uint8 tokenBIndex;
            (tokenAIndex, tokenBIndex) = getTokensIndicesFromPool(pool, tokenPath[i-1], tokenPath[i]);
            SwapFlashLoanV3(pool).swap(tokenAIndex, tokenBIndex, expectedDys[i-1], expectedDys[i], deadline);
        }
        IERC20 tokenB = IERC20(tokenPath[tokenPath.length - 1]);
        tokenB.transfer(msg.sender, expectedDys[expectedDys.length - 1]);
    }
}