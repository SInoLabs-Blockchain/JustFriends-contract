// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface JustFriendsInterface {
    // DATA STRUCTURES
    enum VoteType {
        NONE,
        DOWNVOTE,
        UPVOTE
    }

    struct Content {
        bytes32 contentHash;
        uint256 accessTokenId;
        address creator;
        uint256 startedPrice;
        uint256 totalUpvote;
        uint256 totalDownvote;
        uint256 totalSupply;
    }

    struct Creator {
        address walletAddress;
        uint256 totalContent;
        uint256 totalUpvote;
        uint256 totalDownvote;
    }

    struct Period {
        uint256 revenue;
        address[] loyalFans;
        bool isClose;
    }

    struct LoyalFanRecord {
        uint256 loyalty;
        bool claimed;
    }

    // EVENTS
    event ContentCreated(
        bytes32 indexed hash,
        address indexed creator,
        uint256 startedPrice
    );

    event AccessPurchased(
        bytes32 indexed hash,
        address indexed buyer,
        uint256 amount,
        uint256 totalPrice
    );

    event AccessSold(
        bytes32 indexed hash,
        address indexed seller,
        uint256 amount,
        uint256 totalPrice
    );

    event Upvoted(bytes32 indexed hash, address indexed account);

    event Downvoted(bytes32 indexed hash, address indexed account);

    // ERRORS
    error InvalidContent(bytes32 contentHash);

    error ExistedCreator(address walletAddress);
    error InvalidCreator(address walletAddress);

    error PaidContentVoting(address walletAddress, bytes32 contentHash);
    error InvalidVoting(address walletAddress, bytes32 contentHash);
    error DuplicateVoting(address walletAddress, bytes32 contentHash);

    error EarlyClaiming(address user, address creator, uint256 periodTimestamp);
    error DuplicateClaiming(
        address user,
        address creator,
        uint256 periodTimestamp
    );
    error IllegalClaiming(
        address user,
        address creator,
        uint256 periodTimestamp
    );

    error FreeContentExchange(address walletAddress, bytes32 contentHash);
    error InsufficientPayment(
        address walletAddress,
        bytes32 contentHash,
        uint256 amount
    );
    error InsufficientAccess(
        address walletAddress,
        bytes32 contentHash,
        uint256 amount
    );
    error InvalidFirstPurchase(address walletAddress, bytes32 contentHash);
    error InvalidLastSell(address walletAddress, bytes32 contentHash);
    error FailedFeeTransfer();
}
