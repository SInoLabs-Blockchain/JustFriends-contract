// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

interface IPost {
    event PostCreated(
        bytes32 indexed hash,
        address indexed creator,
        uint256 startedPrice
    );
    event PostBought(
        bytes32 indexed hash,
        address indexed buyer,
        uint256 numberOfPosts,
        uint256 totalPrice
    );
    event PostSold(
        bytes32 indexed hash,
        address indexed seller,
        uint256 numberOfPosts,
        uint256 totalPrice
    );
    event Upvoted(bytes32 indexed hash, address indexed account);
    event Downvoted(bytes32 indexed hash, address indexed account);
}
