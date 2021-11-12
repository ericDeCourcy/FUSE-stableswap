const { expect } = require("chai");

describe("SwapV3-test", function () {
    this.enableTimeouts(false); //TODO do we want this? Why?

    // Deploy all fake tokens

    // Approve all fake tokens


    // Pool deploys correctly
        // deploy libraries and reference contracts
        // deploy pool
        // check that pool deploy succeeded and code exists

    // Pool initializes correctly
        // call initialize
        // check them thar variables got initialized

    // Pool allows deposit
        // do deposit
        // check success
        // check presence of LP tokens in account

    // Pool allows withdrawal
        // do withdraw
        // check LP tokens taken away
        // check token balances increase

    // Pool allows imbalanced withdraw

    // Pool allows single token withdraw

    // Pool allows LP cap setting

    // Pool allows admin variable changes

    // Pool allows switching admin

});