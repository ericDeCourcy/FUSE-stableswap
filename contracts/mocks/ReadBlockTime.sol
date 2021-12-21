pragma solidity 0.6.12;

contract ReadBlockTime {

    function readBlockTime() public returns (uint256)
    {
        return now;
    }
}