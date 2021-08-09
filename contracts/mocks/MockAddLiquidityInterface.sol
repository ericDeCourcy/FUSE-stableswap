pragma solidity 0.6.12;

contract MockAddLiquidityInterface {

    uint256 dumbBuffer; //we use this so that the addLiquidity function modifies state and can't be treated as view

    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns(uint256)
    {
        dumbBuffer += minToMint;
        return dumbBuffer;
    }
}