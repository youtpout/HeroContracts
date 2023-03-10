// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "./IERC20.sol";
import "./IERC721.sol";
import "./IERC1155.sol";

contract GameManagerV2 is AccessControlEnumerableUpgradeable {
    enum ActionType {
        Burn,
        Mint,
        Transfer,
        Call
    }

    enum ContractType {
        Erc20,
        Erc721,
        Erc1155,
        Other
    }

    struct Action {
        ContractType contractType;
        ActionType actionType;
        address contractAddress;
        address spender;
        address recipient;
        uint256 tokenId;
        uint256 amount;
        bytes data;
    }

    bytes32 public constant MASTER_ROLE = keccak256("MASTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function initialize() external initializer {
        __AccessControlEnumerable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MASTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    function executeActions(Action[] calldata actions)
        public
        onlyRole(MASTER_ROLE)
    {
        for (uint256 i = 0; i < actions.length; i++) {
            Action memory currentAction = actions[i];
            if (currentAction.contractType == ContractType.Erc20) {
                IERC20 erc20 = IERC20(currentAction.contractAddress);
                if (currentAction.actionType == ActionType.Burn) {
                    erc20.burnFrom(currentAction.spender, currentAction.amount);
                } else if (currentAction.actionType == ActionType.Mint) {
                    erc20.mint(currentAction.recipient, currentAction.amount);
                } else if (currentAction.actionType == ActionType.Transfer) {
                    bool success = erc20.transferFrom(
                        currentAction.spender,
                        currentAction.recipient,
                        currentAction.amount
                    );
                    require(success, "Transfer failed");
                }
            } else if (currentAction.contractType == ContractType.Erc721) {
                IERC721 erc721 = IERC721(currentAction.contractAddress);
                if (currentAction.actionType == ActionType.Burn) {
                    erc721.burn(currentAction.tokenId);
                } else if (currentAction.actionType == ActionType.Mint) {
                    erc721.mint(currentAction.recipient);
                } else if (currentAction.actionType == ActionType.Transfer) {
                    erc721.safeTransferFrom(
                        currentAction.spender,
                        currentAction.recipient,
                        currentAction.tokenId,
                        currentAction.data
                    );
                }
            } else if (currentAction.contractType == ContractType.Erc1155) {
                IERC1155 erc1155 = IERC1155(currentAction.contractAddress);
                if (currentAction.actionType == ActionType.Burn) {
                    erc1155.burn(
                        currentAction.spender,
                        currentAction.tokenId,
                        currentAction.amount
                    );
                } else if (currentAction.actionType == ActionType.Mint) {
                    erc1155.mint(
                        currentAction.recipient,
                        currentAction.tokenId,
                        currentAction.amount,
                        currentAction.data
                    );
                } else if (currentAction.actionType == ActionType.Transfer) {
                    erc1155.safeTransferFrom(
                        currentAction.spender,
                        currentAction.recipient,
                        currentAction.tokenId,
                        currentAction.amount,
                        currentAction.data
                    );
                }
            } else if (currentAction.contractType == ContractType.Other) {
                if (currentAction.actionType == ActionType.Call) {
                    (bool success, ) = address(currentAction.contractAddress)
                        .call(currentAction.data);
                    require(success, "Call failed");
                }
            }
        }
    }
}
