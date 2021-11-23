//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract Wallet is Ownable {
    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }

    mapping(bytes32 => Token) public tokenMapping;

    bytes32[] public tokenList;

    mapping(address => mapping(bytes32 => uint)) public balances;

    modifier tokenExists(bytes32 ticker){
        require(tokenMapping[ticker].tokenAddress != address(0), "Token does not exist!");
        _;
    }

    function addToken(bytes32 ticker, address tokenAddress) external onlyOwner() {
        tokenMapping[ticker]=Token(ticker, tokenAddress);
        tokenList.push(ticker);
    }

    function deposit(uint amount, bytes32 ticker) tokenExists(ticker) external {
        IERC20(tokenMapping[ticker].tokenAddress).transferFrom(msg.sender, address(this), amount);
        balances[msg.sender][ticker]+=amount;

    }

    function depositEth() payable external {
        balances[msg.sender][bytes32("ETH")]+=msg.value;
    }

    
    function withdrawEth(uint amount) external {
        require(balances[msg.sender][bytes32("ETH")] >= amount,'Insuffient balance'); 
        balances[msg.sender][bytes32("ETH")]-=amount;
        payable(msg.sender).transfer(amount);
    }

    function withdraw(uint amount, bytes32 ticker) tokenExists(ticker) external {
        require(balances[msg.sender][ticker]>=amount, "Insufficient Balance!");
        balances[msg.sender][ticker]-=amount;
        IERC20(tokenMapping[ticker].tokenAddress).transfer(msg.sender, amount);
    }
}