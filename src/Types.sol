// Types.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Types {
    enum Category {
        ECOLOGY,
        EDUCATION,
        ECONOMY,
        DEFENSE
    }

    enum Vote {
        NULL,
        NO,
        YES
    }

    enum Status {
        // CREATED, //TODO : For Draft #3
        ENDED,
        ONGOING
    }
}
