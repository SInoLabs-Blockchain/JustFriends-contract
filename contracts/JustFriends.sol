// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./ContentAccessInterface.sol";
import "./JustFriendsInterface.sol";

contract JustFriends is Ownable, JustFriendsInterface {
    address public protocolFeeDestination;
    uint8 public protocolFeePercentBase;
    uint8 public creatorFeePercentBase;
    uint8 public extraFeePercentBase;
    address public contentAccessContract;
    uint256 private _contentCounter = 0;
    uint8 upvoteWeight = 100;
    uint8 downvoteWeight = 80;
    uint8 voteWeight = 25;
    uint32 oneMonth = 2592000;

    constructor(
        address _protocolFeeDestination,
        uint8 _protocolFeePercentBase,
        uint8 _creatorFeePercentBase,
        uint8 _extraFeePercentBase,
        address _contentAccessContract
    ) Ownable(msg.sender) {
        protocolFeeDestination = _protocolFeeDestination;
        contentAccessContract = _contentAccessContract;
        protocolFeePercentBase = _protocolFeePercentBase;
        creatorFeePercentBase = _creatorFeePercentBase;
        extraFeePercentBase = _extraFeePercentBase;
    }

    mapping(bytes32 => Content) public contentList;
    mapping(address => Creator) public creatorList;
    mapping(address => mapping(bytes32 => VoteType)) userReactions;
    mapping(address => mapping(address => mapping(uint256 => LoyalFanRecord))) loyalFanRecords;
    mapping(address => mapping(uint256 => Period)) periodList;

    function _calculateCreditScore(
        uint256 totalUpvotes,
        uint256 totalDownvotes
    ) private view returns (uint256) {
        return totalUpvotes * upvoteWeight - totalDownvotes * downvoteWeight;
    }

    function _calculateContentFees(
        uint256 _creatorCreditScore,
        uint256 _totalVotes,
        uint256 _contentPrice
    ) private view returns (uint256, uint256) {
        uint8 creatorFeePercent = creatorFeePercentBase;
        uint8 protocolFeePercent = protocolFeePercentBase;
        if (_creatorCreditScore > voteWeight * _totalVotes) {
            creatorFeePercent += extraFeePercentBase;
            protocolFeePercent -= extraFeePercentBase;
        }
        return (
            (_contentPrice * creatorFeePercent) / 100,
            (_contentPrice * protocolFeePercent) / 100
        );
    }

    function _updateLoyalFansList(
        address _creator,
        address _user,
        uint256 _periodTimestamp,
        uint256 _loyalty
    ) private {
        Period storage period = periodList[_creator][_periodTimestamp];
        uint256 loyalFanCount = period.loyalFans.length;
        for (uint256 i = 0; i < loyalFanCount; i++) {
            address fan = period.loyalFans[i];
            uint256 fanLoyalty = loyalFanRecords[fan][_creator][
                _periodTimestamp
            ].loyalty;
            if (_loyalty >= fanLoyalty) continue;
            else {
                if (i == loyalFanCount - 1 && loyalFanCount < 20) {
                    period.loyalFans.push(_user);
                } else {
                    if (loyalFanCount == 20) period.loyalFans.pop();
                    for (uint256 j = loyalFanCount - 1; j > i; j--) {
                        period.loyalFans[j] = period.loyalFans[j - 1];
                    }
                    period.loyalFans[i] = _user;
                }
            }
        }
    }

    function getCreatorInfo(
        address _walletAddress
    ) external view returns (address, uint256, uint256, uint256) {
        Creator memory creator = creatorList[_walletAddress];
        return (
            creator.walletAddress,
            creator.totalContent,
            creator.totalUpvote,
            creator.totalDownvote
        );
    }

    function getContentInfo(
        bytes32 _contentHash
    ) external view returns (bytes32, uint256, address, uint256) {
        Content memory content = contentList[_contentHash];
        return (content.contentHash, content.accessTokenId, content.creator, content.totalSupply);
    }

    function getContentPrice(
        uint256 _basePrice,
        uint256 _supply,
        uint256 _amount
    ) public pure returns (uint256) {
        uint256 sum1 = _supply == 0
            ? 0
            : ((_supply - 1) * (_supply) * (2 * (_supply - 1) + 1)) / 6;
        uint256 sum2 = _supply == 0 && _amount == 1
            ? 0
            : ((_supply - 1 + _amount) *
                (_supply + _amount) *
                (2 * (_supply - 1 + _amount) + 1)) / 6;
        uint256 summation = sum2 - sum1;
        return (_basePrice * summation) / 10000;
    }

    function setProtocolFeeDestination(
        address _newProtocolFeeDestination
    ) external onlyOwner {
        protocolFeeDestination = _newProtocolFeeDestination;
    }

    function setVoteWeightBase(
        uint8 _upvoteWeight,
        uint8 _downvoteWeight,
        uint8 _voteWeight
    ) external onlyOwner {
        upvoteWeight = _upvoteWeight;
        downvoteWeight = _downvoteWeight;
        voteWeight = _voteWeight;
    }

    function setFeePercentBase(
        uint8 _newProtocolFeePercentBase,
        uint8 _newCreatorFeePercentBase,
        uint8 _newExtraFeePercentBase
    ) external onlyOwner {
        protocolFeePercentBase = _newProtocolFeePercentBase;
        creatorFeePercentBase = _newCreatorFeePercentBase;
        extraFeePercentBase = _newExtraFeePercentBase;
    }

    function register() external {
        if (creatorList[msg.sender].walletAddress != address(0)) {
            revert ExistedCreator(msg.sender);
        }

        Creator memory newCreator = Creator(msg.sender, 0, 0, 0);
        creatorList[msg.sender] = newCreator;
    }

    function vote(
        bytes32 _contentHash,
        VoteType _voteType,
        uint256 _periodTimestamp
    ) external {
        Content memory content = contentList[_contentHash];
        // User can only vote for free contents
        if (content.startedPrice != 0) {
            revert PaidContentVoting(msg.sender, _contentHash);
        }

        // User can only upvote / downvote
        if (_voteType == VoteType.NONE) {
            revert InvalidVoting(msg.sender, _contentHash);
        }

        // Creator cannot vote for his/her own content
        if (content.creator == msg.sender) {
            revert InvalidVoting(msg.sender, _contentHash);
        }

        Creator memory creator = creatorList[content.creator];
        VoteType previousReaction = userReactions[msg.sender][_contentHash];
        // User can only revote, cannot vote multiple times with the same value
        if (
            previousReaction != VoteType.NONE && previousReaction == _voteType
        ) {
            revert DuplicateVoting(msg.sender, _contentHash);
        }

        Period storage period = periodList[creator.walletAddress][
            _periodTimestamp
        ];
        if (!period.isClose) {
            if (_periodTimestamp + oneMonth <= block.timestamp) {
                // Start a new period and add a new loyal fan record for user if the last period is expired
                period.isClose = true;
                Period storage newPeriod = periodList[creator.walletAddress][
                    block.timestamp
                ];
                newPeriod.loyalFans.push(msg.sender);
                loyalFanRecords[msg.sender][creator.walletAddress][
                    block.timestamp
                ] = LoyalFanRecord(1, false);
            } else {
                // Or else, update loyal fan record for user
                LoyalFanRecord memory loyalFanRecord = loyalFanRecords[
                    msg.sender
                ][creator.walletAddress][_periodTimestamp];
                loyalFanRecord.loyalty += 1;
                _updateLoyalFansList(
                    creator.walletAddress,
                    msg.sender,
                    _periodTimestamp,
                    loyalFanRecord.loyalty
                );
            }
        }

        // Update content upvote/downvote count
        if (_voteType == VoteType.DOWNVOTE) {
            content.totalDownvote += 1;
            creator.totalDownvote += 1;
            emit Downvoted(_contentHash, msg.sender);
        } else {
            content.totalUpvote += 1;
            creator.totalUpvote += 1;
            emit Upvoted(_contentHash, msg.sender);
        }
        userReactions[msg.sender][_contentHash] = _voteType;
    }

    function claim(address _creator, uint256 _periodTimestamp) external {
        LoyalFanRecord memory loyalFanRecord = loyalFanRecords[msg.sender][
            _creator
        ][_periodTimestamp];
        if (loyalFanRecord.claimed) {
            revert DuplicateClaiming(msg.sender, _creator, _periodTimestamp);
        }
        if (block.timestamp < _periodTimestamp + oneMonth) {
            revert EarlyClaiming(msg.sender, _creator, _periodTimestamp);
        }
        Period memory period = periodList[_creator][_periodTimestamp];
        if (!period.isClose) {
            period.isClose = true;
        }
        for (uint8 i = 0; i < period.loyalFans.length; i++) {
            if (period.loyalFans[i] == msg.sender) {
                uint256 revenue = period.revenue / 20;
                (bool success, ) = msg.sender.call{value: revenue}("");
                if (!success) {
                    revert FailedFeeTransfer();
                }
                return;
            }
        }
        revert IllegalClaiming(msg.sender, _creator, _periodTimestamp);
    }

    function postContent(bytes32 _contentHash, uint256 _startedPrice) external {
        if (creatorList[msg.sender].walletAddress == address(0)) {
            revert InvalidCreator(msg.sender);
        }

        Content memory newContent = Content(
            _contentHash,
            _contentCounter,
            msg.sender,
            _startedPrice,
            0,
            0,
            0
        );
        contentList[_contentHash] = newContent;
        _contentCounter++;

        Creator memory creator = creatorList[msg.sender];
        creator.totalContent++;

        emit ContentCreated(_contentHash, msg.sender, _startedPrice);
    }

    function buyContentAccess(
        bytes32 _contentHash,
        uint256 _amount
    ) external payable {
        Content storage content = contentList[_contentHash];
        if (content.creator == address(0)) {
            revert InvalidContent(_contentHash);
        }

        if (content.startedPrice == 0) {
            revert FreeContentExchange(msg.sender, _contentHash);
        }

        if (content.totalSupply == 0 && msg.sender != content.creator) {
            revert InvalidFirstPurchase(msg.sender, _contentHash);
        }

        Creator memory creator = creatorList[content.creator];
        uint256 contentPrice = getContentPrice(content.startedPrice, content.totalSupply, _amount);
        uint256 creatorCreditScore = _calculateCreditScore(
            creator.totalUpvote,
            creator.totalDownvote
        );
        (uint256 creatorFee, uint256 protocolFee) = _calculateContentFees(
            creatorCreditScore,
            creator.totalUpvote + creator.totalDownvote,
            contentPrice
        );
        if (msg.value < contentPrice + creatorFee + protocolFee) {
            revert InsufficientPayment(
                msg.sender,
                _contentHash,
                msg.value
            );
        }

        content.totalSupply += _amount;
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = creator.walletAddress.call{value: creatorFee}("");
        if (!success1 || !success2) {
            revert FailedFeeTransfer();
        }

        ContentAccessInterface contentAccessInstance = ContentAccessInterface(
            contentAccessContract
        );
        contentAccessInstance.grantAccess(msg.sender, content.accessTokenId, _amount);

        emit AccessPurchased(_contentHash, msg.sender, _amount, contentPrice);
    }

    function sellContentAccess(bytes32 _contentHash, uint256 _amount) external {
        Content storage content = contentList[_contentHash];
        if (content.creator == address(0)) {
            revert InvalidContent(_contentHash);
        }

        if (content.startedPrice == 0) {
            revert FreeContentExchange(msg.sender, _contentHash);
        }

        if (content.totalSupply <= _amount) {
            revert InvalidLastSell(msg.sender, _contentHash);
        }

        ContentAccessInterface contentAccessInstance = ContentAccessInterface(
            contentAccessContract
        );
        if (
            contentAccessInstance.balanceOf(
                msg.sender,
                content.accessTokenId
            ) <= _amount
        ) {
            revert InsufficientAccess(msg.sender, _contentHash, _amount);
        }

        Creator memory creator = creatorList[content.creator];
        uint256 contentPrice = getContentPrice(content.startedPrice, content.totalSupply - _amount, _amount);
        uint256 creatorCreditScore = _calculateCreditScore(
            creator.totalUpvote,
            creator.totalDownvote
        );
        (uint256 creatorFee, uint256 protocolFee) = _calculateContentFees(
            creatorCreditScore,
            creator.totalUpvote + creator.totalDownvote,
            contentPrice
        );

        content.totalSupply -= _amount;
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = creator.walletAddress.call{value: creatorFee}("");
        (bool success3, ) = msg.sender.call{
            value: contentPrice - creatorFee - protocolFee
        }("");
        if (!success1 || !success2 || !success3) {
            revert FailedFeeTransfer();
        }

        contentAccessInstance.revokeAccess(msg.sender, content.accessTokenId, _amount);

        emit AccessSold(_contentHash, msg.sender, _amount, contentPrice - creatorFee - protocolFee);
    }
}
