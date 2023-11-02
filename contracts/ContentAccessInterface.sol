// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface ContentAccessInterface is IERC1155 {
    function grantAccess(
        address _to,
        uint256 _contentId,
        uint256 _value
    ) external;

    function revokeAccess(
        address _from,
        uint256 _contentId,
        uint256 _value
    ) external;
}
