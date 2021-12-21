pragma solidity 0.6.12;

import "./contracts-v3_4/token/ERC20/IERC20.sol";

contract RoutableSwapWrapper {

    address constant public underlyingPool;

    constructor(address[] _tokens, address _underlyingPool) external
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
     * @dev this assumes that the tokens for the swap are already present in this contract
     */
    // TODO: is there any problem with sending all the tokens this contract posesses? 
    //      only problem i can see is if there's some requirement that the number of tokens isn't greater than x

    // function getAmountOut
    // TODO:should name match uniswap router or nah?
    /**
     * @dev For calling into the swap contract, this needs to use token indices
     *      However for better interoperability we should have an input here be the token addresses
     */


}