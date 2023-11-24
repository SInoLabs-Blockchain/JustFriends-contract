// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./ContentAccessInterface.sol";
import "./JustFriendsInterface.sol";
import "./token/NonTransferableERC1155.sol";

contract JustFriends is NonTransferableERC1155, JustFriendsInterface {
    uint256 public constant MAX_UINT256 = type(uint256).max;
    address public protocolFeeDestination;
    uint8 public protocolFeePercentBase;
    uint8 public creatorFeePercentBase;
    uint8 public extraFeePercentBase;
    uint8 public loyalFanFeePercentBase;
    uint256 private _contentCounter = 0;
    uint8 upvoteWeight = 100;
    uint8 downvoteWeight = 80;
    uint8 voteWeight = 25;
    uint32 periodBlock = 100000;
    uint8 loyalFanLength = 3;

    constructor(
        address _protocolFeeDestination,
        uint8 _protocolFeePercentBase,
        uint8 _creatorFeePercentBase,
        uint8 _extraFeePercentBase,
        uint8 _loyalFanFeePercentBase,
        uint8 _loyalFanLength
    ) NonTransferableERC1155("") {
        protocolFeeDestination = _protocolFeeDestination;
        protocolFeePercentBase = _protocolFeePercentBase;
        creatorFeePercentBase = _creatorFeePercentBase;
        extraFeePercentBase = _extraFeePercentBase;
        loyalFanFeePercentBase = _loyalFanFeePercentBase;
        loyalFanLength = _loyalFanLength;
    }

    mapping(bytes32 => Content) public contentList;
    mapping(address => Creator) public creatorList;
    mapping(address => mapping(bytes32 => VoteType)) public userReactions;
    mapping(address => mapping(address => mapping(uint256 => LoyalFanRecord))) public loyalFanRecords;
    mapping(address => mapping(uint256 => Period)) public periodList;

    function _calculateCreditScore(uint256 totalUpvotes, uint256 totalDownvotes) private view returns (uint256) {
        return totalUpvotes * upvoteWeight - totalDownvotes * downvoteWeight;
    }

    function _calculateContentFees(
        uint256 _creatorCreditScore,
        uint256 _totalVotes,
        uint256 _contentPrice
    ) private view returns (uint256, uint256, uint256) {
        uint8 creatorFeePercent = creatorFeePercentBase;
        uint8 protocolFeePercent = protocolFeePercentBase;
        if (_creatorCreditScore > voteWeight * _totalVotes) {
            creatorFeePercent += extraFeePercentBase;
            protocolFeePercent -= extraFeePercentBase;
        }
        return (
            (_contentPrice * creatorFeePercent) / 100,
            (_contentPrice * protocolFeePercent) / 100,
            (_contentPrice * loyalFanFeePercentBase) / 100
        );
    }

    function _updateLoyalFansList(address _creator, address _user, uint256 _periodId, uint256 _loyalty) private {
        Period storage period = periodList[_creator][_periodId];
        uint256 loyalFanCount = period.loyalFans.length;
        if (loyalFanCount == 0) {
            period.loyalFans.push(_user);
            return;
        }
        uint256 smallestLoyaltyFanIdInList = loyalFanCount;
        uint256 smallestLoyaltyPointInList = MAX_UINT256;
        for (uint256 i = 0; i < loyalFanCount; i++) {
            address fan = period.loyalFans[i];
            if (fan == _user) return;
            uint256 fanLoyalty = loyalFanRecords[fan][_creator][_periodId].loyalty;
            if (fanLoyalty <= smallestLoyaltyPointInList) {
                smallestLoyaltyPointInList = fanLoyalty;
                smallestLoyaltyFanIdInList = i;
            }
        }

        if (loyalFanCount < loyalFanLength) {
            period.loyalFans.push(_user);
            return;
        }
        if (loyalFanCount >= loyalFanLength && _loyalty > smallestLoyaltyPointInList) {
            period.loyalFans[smallestLoyaltyFanIdInList] = _user;
        }
    }

    function getListLoyalty(address _creator, uint256 _periodId) public view returns (address[] memory) {
        return periodList[_creator][_periodId].loyalFans;
    }

    function getCreatorInfo(address _walletAddress) external view returns (uint256, uint256, uint256) {
        Creator memory creator = creatorList[_walletAddress];
        return (creator.totalContent, creator.totalUpvote, creator.totalDownvote);
    }

    function getContentsInfo(bytes32[] memory _contentHashes) external view returns (Content[] memory) {
        Content[] memory result = new Content[](_contentHashes.length);
        for (uint256 i = 0; i < _contentHashes.length; i++) {
            Content memory content = contentList[_contentHashes[i]];
            result[i] = content;
        }
        return result;
    }

    function getContentPrice(uint256 _basePrice, uint256 _supply, uint256 _amount) public pure returns (uint256) {
        uint256 sum1 = _supply == 0 ? 0 : ((_supply - 1) * (_supply) * (2 * (_supply - 1) + 1)) / 6;
        uint256 sum2 = _supply == 0 && _amount == 1
            ? 0
            : ((_supply - 1 + _amount) * (_supply + _amount) * (2 * (_supply - 1 + _amount) + 1)) / 6;
        uint256 summation = sum2 - sum1;
        return _basePrice + ((summation * 1 ether) / 100);
    }

    function getBuyPrice(
        bytes32[] memory _contentHashes,
        uint256[] memory _amounts
    ) public view returns (uint256[] memory) {
        uint256[] memory results = new uint256[](_contentHashes.length);
        for (uint256 i = 0; i < _contentHashes.length; i++) {
            Content memory content = contentList[_contentHashes[i]];
            uint256 contentPrice = getContentPrice(content.startedPrice, content.totalSupply, _amounts[i]);
            results[i] =
                (contentPrice * (creatorFeePercentBase + protocolFeePercentBase + loyalFanFeePercentBase + 100)) /
                100;
        }
        return results;
    }

    function getSellPrice(
        bytes32[] memory _contentHashes,
        uint256[] memory _amounts
    ) public view returns (uint256[] memory) {
        uint256[] memory results = new uint256[](_contentHashes.length);
        for (uint256 i = 0; i < _contentHashes.length; i++) {
            Content memory content = contentList[_contentHashes[i]];
            uint256 contentPrice = getContentPrice(
                content.startedPrice,
                content.totalSupply - _amounts[i],
                _amounts[i]
            );
            results[i] =
                (contentPrice * (creatorFeePercentBase + protocolFeePercentBase + loyalFanFeePercentBase + 100)) /
                100;
        }
        return results;
    }

    function setProtocolFeeDestination(address _newProtocolFeeDestination) external onlyOwner {
        protocolFeeDestination = _newProtocolFeeDestination;
    }

    function setVoteWeightBase(uint8 _upvoteWeight, uint8 _downvoteWeight, uint8 _voteWeight) external onlyOwner {
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

    function vote(bytes32 _contentHash, VoteType _voteType) external {
        Content storage content = contentList[_contentHash];
        // User can only vote for free contents
        if (content.isPaid == true) {
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

        Creator storage creator = creatorList[content.creator];
        VoteType previousReaction = userReactions[msg.sender][_contentHash];
        // User can only revote, cannot vote multiple times with the same value
        if (previousReaction != VoteType.NONE && previousReaction == _voteType) {
            revert DuplicateVoting(msg.sender, _contentHash);
        }
        uint256 periodId = block.number / periodBlock;
        if (periodId > 0) {
            uint256 latestPeriodId = periodId - 1;
            Period storage latestPeriod = periodList[content.creator][latestPeriodId];
            // close lastest period if it wasn't closed
            if (!latestPeriod.isClose) latestPeriod.isClose = true;
        }
        // calculate loyal score and update loyal list
        LoyalFanRecord storage currentLoyalFanRecord = loyalFanRecords[msg.sender][content.creator][periodId];
        currentLoyalFanRecord.loyalty++;
        _updateLoyalFansList(content.creator, msg.sender, periodId, currentLoyalFanRecord.loyalty);
        // calculate total vote for this post
        // Update content upvote/downvote count
        if (_voteType == VoteType.DOWNVOTE) {
            if (previousReaction == VoteType.UPVOTE) {
                content.totalUpvote--;
                creator.totalUpvote--;
            }
            content.totalDownvote++;
            creator.totalDownvote++;
            emit Downvoted(_contentHash, msg.sender, content.creator);
        } else if (_voteType == VoteType.UPVOTE) {
            if (previousReaction == VoteType.DOWNVOTE) {
                content.totalDownvote--;
                creator.totalDownvote--;
            }
            content.totalUpvote++;
            creator.totalUpvote++;
            emit Upvoted(_contentHash, msg.sender, content.creator);
        }
        // marking the vote for this post
        userReactions[msg.sender][_contentHash] = _voteType;
    }

    function claim(address _creator, uint256 _periodId) external {
        LoyalFanRecord memory loyalFanRecord = loyalFanRecords[msg.sender][_creator][_periodId];
        if (loyalFanRecord.claimed) {
            revert DuplicateClaiming(msg.sender, _creator, _periodId);
        }
        if (block.number / periodBlock <= _periodId) {
            revert EarlyClaiming(msg.sender, _creator, _periodId);
        }
        Period memory period = periodList[_creator][_periodId];
        if (!periodList[_creator][_periodId].isClose) {
            revert UnCloseClaiming(msg.sender, _creator, _periodId);
        }
        if (!period.isClose) {
            period.isClose = true;
        }

        for (uint8 i = 0; i < period.loyalFans.length; i++) {
            if (period.loyalFans[i] == msg.sender) {
                uint256 revenue = period.revenue / loyalFanLength;
                (bool success, ) = msg.sender.call{value: revenue}("");
                if (!success) {
                    revert FailedFeeTransfer();
                }
                return;
            }
        }
        revert IllegalClaiming(msg.sender, _creator, _periodId);
    }

    function postContent(bytes32 _contentHash, uint256 _startedPrice, bool isPaid) external {
        if (contentList[_contentHash].totalSupply != 0) {
            revert InvalidContent(_contentHash);
        }
        ++_contentCounter;
        contentList[_contentHash] = Content(_contentHash, _contentCounter, msg.sender, isPaid, _startedPrice, 0, 0, 1);
        _mint(msg.sender, _contentCounter, 1, "");

        creatorList[msg.sender].totalContent++;

        emit ContentCreated(_contentHash, msg.sender, _startedPrice, isPaid);
    }

    function buyContentAccess(bytes32 _contentHash, uint256 _amount) external payable {
        Content storage content = contentList[_contentHash];
        if (content.creator == address(0)) {
            revert InvalidContent(_contentHash);
        }
        if (!content.isPaid) {
            revert FreeContentExchange(msg.sender, _contentHash);
        }
        if (msg.sender == content.creator) {
            revert InvalidContent(_contentHash);
        }
        // start update loyalty point
        uint256 periodId = block.number / periodBlock;
        if (periodId > 0) {
            uint256 latestPeriodId = periodId - 1;
            Period storage latestPeriod = periodList[content.creator][latestPeriodId];
            // close lastest period if it wasn't closed
            if (!latestPeriod.isClose) latestPeriod.isClose = true;
        }
        // calculate loyal score and update loyal list
        LoyalFanRecord storage currentLoyalFanRecord = loyalFanRecords[msg.sender][content.creator][periodId];
        currentLoyalFanRecord.loyalty = currentLoyalFanRecord.loyalty + 3 * _amount;
        _updateLoyalFansList(content.creator, msg.sender, periodId, currentLoyalFanRecord.loyalty);

        Creator memory creator = creatorList[content.creator];
        uint256 contentPrice = getContentPrice(content.startedPrice, content.totalSupply, _amount);
        uint256 creatorCreditScore = _calculateCreditScore(creator.totalUpvote, creator.totalDownvote);
        (uint256 creatorFee, uint256 protocolFee, uint256 loyalFee) = _calculateContentFees(
            creatorCreditScore,
            creator.totalUpvote + creator.totalDownvote,
            contentPrice
        );
        uint256 totalPrice = contentPrice + creatorFee + protocolFee + loyalFee;
        if (msg.value < totalPrice) {
            revert InsufficientPayment(msg.sender, _contentHash, msg.value);
        }

        content.totalSupply += _amount;
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = content.creator.call{value: creatorFee}("");
        if (!success1 || !success2) {
            revert FailedFeeTransfer();
        }
        periodList[content.creator][periodId].revenue += loyalFee;
        _mint(msg.sender, content.accessTokenId, _amount, "");

        emit AccessPurchased(_contentHash, msg.sender, _amount, totalPrice);
    }

    function sellContentAccess(bytes32 _contentHash, uint256 _amount) external {
        Content storage content = contentList[_contentHash];
        if (content.creator == address(0)) {
            revert InvalidContent(_contentHash);
        }

        if (!content.isPaid) {
            revert FreeContentExchange(msg.sender, _contentHash);
        }

        if (msg.sender == content.creator) {
            revert InvalidContent(_contentHash);
        }

        if (balanceOf(msg.sender, content.accessTokenId) < _amount) {
            revert InsufficientAccess(msg.sender, _contentHash, _amount);
        }
        // start update loyalty point
        uint256 periodId = block.number / periodBlock;
        if (periodId > 0) {
            uint256 latestPeriodId = periodId - 1;
            Period storage latestPeriod = periodList[content.creator][latestPeriodId];
            // close lastest period if it wasn't closed
            if (!latestPeriod.isClose) latestPeriod.isClose = true;
        }
        Creator memory creator = creatorList[content.creator];
        uint256 contentPrice = getContentPrice(content.startedPrice, content.totalSupply - _amount, _amount);
        uint256 creatorCreditScore = _calculateCreditScore(creator.totalUpvote, creator.totalDownvote);
        (uint256 creatorFee, uint256 protocolFee, uint256 loyalFee) = _calculateContentFees(
            creatorCreditScore,
            creator.totalUpvote + creator.totalDownvote,
            contentPrice
        );
        uint256 receiveAmount = contentPrice - creatorFee - protocolFee - loyalFee;
        periodList[content.creator][periodId].revenue += loyalFee;

        content.totalSupply -= _amount;
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = content.creator.call{value: creatorFee}("");
        (bool success3, ) = msg.sender.call{value: receiveAmount}("");
        if (!success1 || !success2 || !success3) {
            revert FailedFeeTransfer();
        }

        _burn(msg.sender, content.accessTokenId, _amount);

        emit AccessSold(_contentHash, msg.sender, _amount, receiveAmount);
    }
}
