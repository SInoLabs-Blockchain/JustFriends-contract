// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./token/NonTransferableERC1155.sol";

contract ContentAccess is NonTransferableERC1155 {
    constructor(string memory uri) NonTransferableERC1155(uri) {}

    function grantAccess(
        address _to,
        uint256 _contentId,
        uint256 _value
    ) external {
        _mint(_to, _contentId, _value, "");
    }

    function revokeAccess(
        address _from,
        uint256 _contentId,
        uint256 _value
    ) external {
        _burn(_from, _contentId, _value);
    }
}
