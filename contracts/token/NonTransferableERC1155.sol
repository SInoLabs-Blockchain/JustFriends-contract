// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NonTransferableERC1155 is ERC1155, Ownable {
    constructor(string memory uri) ERC1155(uri) {}

    function mint(uint256 id, uint256 amount, bytes memory data) public {
        _mint(msg.sender, id, amount, data);
    }

    function mintBatch(
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public {
        _mintBatch(msg.sender, ids, amounts, data);
    }

    function burn(uint256 id, uint256 amount) public {
        _burn(msg.sender, id, amount);
    }

    function burnBatch(uint256[] memory ids, uint256[] memory amounts) public {
        _burnBatch(msg.sender, ids, amounts);
    }

    function setURI(string memory newURI) public onlyOwner {
        _setURI(newURI);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        require(
            from == address(0) || to == address(0),
            "Token transfers are not allowed."
        );
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
