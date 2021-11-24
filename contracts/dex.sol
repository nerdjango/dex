//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./wallet.sol";

contract Dex is Wallet {
    enum Side {
        BUY,
        SELL
    }
    struct Order {
        uint id;
        address trader;
        Side side;
        bytes32 ticker;
        uint amount;
        uint price;
        uint filled;
    }

    uint public nextOrderId=0;

    mapping(bytes32 => mapping(uint => Order[])) public orderBook;

    function getOrderBook(bytes32 ticker, Side side) view public returns(Order[] memory) {
        return orderBook[ticker][uint(side)];
    }
    function createLimitOrder(Side side, bytes32 ticker, uint amount, uint price) public {
        if (side == Side.BUY){
            require(balances[msg.sender]["ETH"] >= amount*price);
        } else if (side == Side.SELL){
            require(balances[msg.sender][ticker] >= amount);
        }
        
        uint remainder=_fillLimitOrder(side, ticker, amount, price);

        if (remainder>0){
            Order[] storage orders = orderBook[ticker][uint(side)];
            orders.push(
                Order(nextOrderId, msg.sender, side, ticker, amount, price, amount-remainder)
            );

            //Bubble sort [300, 100, 200]
            if(side==Side.BUY){
                for (uint i=orders.length-1; i>0; i--) {
                    if (orders[i-1].price < orders[i].price){
                        Order memory less=orders[i-1];
                        orders[i-1]=orders[i];
                        orders[i]=less;
                    }
                }
            } else if (side==Side.SELL){
                for (uint i=orders.length-1; i>0; i--) {
                    if (orders[i-1].price > orders[i].price){
                        Order memory great=orders[i-1];
                        orders[i-1]=orders[i];
                        orders[i]=great;
                    }
                }
            }


            nextOrderId++;
        }
    }

    function _fillLimitOrder(Side side, bytes32 ticker, uint amount, uint price) private returns(uint){
        uint reverseOrderBookSide;
        if (side==Side.BUY) {
            reverseOrderBookSide=1;
        } else if (side==Side.SELL) {
            require(balances[msg.sender][ticker]>=amount, "Insufficient balance");
            reverseOrderBookSide=0;
        }
        Order[] storage reverseOrders = orderBook[ticker][reverseOrderBookSide];
        uint remainder=amount;
        for (uint i=0; i<reverseOrders.length && remainder>0; i++){
            if (reverseOrders[i].price==price){
                uint reverseFillAmount=reverseOrders[i].amount-reverseOrders[i].filled;
                if (remainder > reverseFillAmount){
                    if (side==Side.BUY) {
                        require(balances[msg.sender]["ETH"]>=(reverseFillAmount*price), "Insufficient ETH balance");
                        require(balances[reverseOrders[i].trader][ticker]>=reverseFillAmount, "Seller has insufficient Token balance");
                        balances[msg.sender]["ETH"]-=(reverseFillAmount*price);
                        balances[msg.sender][ticker]+=reverseFillAmount;
                        balances[reverseOrders[i].trader]["ETH"]+=(reverseFillAmount*price);
                        balances[reverseOrders[i].trader][ticker]-=reverseFillAmount;
                        reverseOrders[i].filled+=reverseFillAmount;
                        remainder-=reverseFillAmount;
                    }else if (side==Side.SELL){
                        require(balances[msg.sender][ticker]>=reverseFillAmount, "Insufficient Token balance");
                        require(balances[reverseOrders[i].trader]["ETH"]>=(reverseFillAmount*price), "Buyer has insufficient ETH balance");
                        balances[msg.sender][ticker]-=reverseFillAmount;
                        balances[msg.sender]["ETH"]+=(reverseFillAmount*price);
                        balances[reverseOrders[i].trader][ticker]+=reverseFillAmount;
                        balances[reverseOrders[i].trader]["ETH"]-=(reverseFillAmount*price);
                        reverseOrders[i].filled+=reverseFillAmount;
                        remainder-=reverseFillAmount;
                    }
                }else{
                    if (side==Side.BUY) {
                        require(balances[msg.sender]["ETH"]>=(price*remainder), "Insufficient ETH balance");
                        require(balances[reverseOrders[i].trader][ticker]>=remainder, "Seller has insufficient Token balance");
                        balances[msg.sender]["ETH"]-=(price*remainder);
                        balances[msg.sender][ticker]+=remainder;
                        balances[reverseOrders[i].trader]["ETH"]+=(price*remainder);
                        balances[reverseOrders[i].trader][ticker]-=remainder;
                        reverseOrders[i].filled+=remainder;
                        remainder=0;
                    }else if (side==Side.SELL){
                        require(balances[msg.sender][ticker]>=remainder, "Insufficient Token balance");
                        require(balances[reverseOrders[i].trader]["ETH"]>=(remainder*price), "Buyer has insufficient ETH balance");
                        balances[msg.sender][ticker]-=remainder;
                        balances[msg.sender]["ETH"]+=(remainder*price);
                        balances[reverseOrders[i].trader][ticker]+=remainder;
                        balances[reverseOrders[i].trader]["ETH"]-=(remainder*price);
                        reverseOrders[i].filled+=remainder;
                        remainder=0;
                    }
                    
                }
            }
        }

        for (uint i=reverseOrders.length; i>0; i--){
            if (reverseOrders[i-1].amount==reverseOrders[i-1].filled) {
                for (uint j=i-1; j<reverseOrders.length-1; j++){
                    reverseOrders[j] = reverseOrders[j+1];
                }
                reverseOrders.pop();
            }
        }

        return remainder;

    }

    function createMarketOrder(Side side, bytes32 ticker, uint amount) public{
        uint orderBookSide;
        if (side==Side.BUY) {
            orderBookSide=1;
        } else if (side==Side.SELL) {
            require(balances[msg.sender][ticker]>=amount, "Insufficient balance");
            orderBookSide=0;
        }
        Order[] storage orders = orderBook[ticker][orderBookSide];

        uint remainder=amount;

        for (uint i=0; i<orders.length && remainder>0 ; i++) {
            uint fillAmount=orders[i].amount-orders[i].filled;
            if(side==Side.BUY){
                uint estimatePrice;
                if (remainder > fillAmount) {
                    estimatePrice+=(orders[i].price*fillAmount);
                    require(balances[msg.sender]["ETH"]>=estimatePrice, "Insufficient ETH balance");
                    require(balances[orders[i].trader][ticker]>=fillAmount, "Seller has insufficient Token balance");
                    balances[msg.sender]["ETH"]-=estimatePrice;
                    balances[msg.sender][ticker]+=fillAmount;
                    balances[orders[i].trader]["ETH"]+=estimatePrice;
                    balances[orders[i].trader][ticker]-=fillAmount;
                    orders[i].filled+=fillAmount;
                    remainder-=fillAmount;
                }else{
                    estimatePrice+=(orders[i].price*remainder);
                    require(balances[msg.sender]["ETH"]>=estimatePrice, "Insufficient ETH balance");
                    require(balances[orders[i].trader][ticker]>=remainder, "Seller has insufficient Token balance");
                    balances[msg.sender]["ETH"]-=estimatePrice;
                    balances[msg.sender][ticker]+=remainder;
                    balances[orders[i].trader]["ETH"]+=estimatePrice;
                    balances[orders[i].trader][ticker]-=remainder;
                    orders[i].filled+=remainder;
                    remainder=0;
                }
            } else if (side==Side.SELL){
                if (remainder > fillAmount) {
                    require(balances[msg.sender][ticker]>=fillAmount, "Insufficient Token balance");
                    require(balances[orders[i].trader]["ETH"]>=(fillAmount*orders[i].price), "Buyer has insufficient ETH balance");
                    balances[msg.sender][ticker]-=fillAmount;
                    balances[msg.sender]["ETH"]+=(fillAmount*orders[i].price);
                    balances[orders[i].trader][ticker]+=fillAmount;
                    balances[orders[i].trader]["ETH"]-=(fillAmount*orders[i].price);
                    orders[i].filled+=fillAmount;
                    remainder-=fillAmount;
                }else{
                    require(balances[msg.sender][ticker]>=remainder, "Insufficient Token balance");
                    require(balances[orders[i].trader]["ETH"]>=(remainder*orders[i].price), "Buyer has insufficient ETH balance");
                    balances[msg.sender][ticker]-=remainder;
                    balances[msg.sender]["ETH"]+=(remainder*orders[i].price);
                    balances[orders[i].trader][ticker]+=remainder;
                    balances[orders[i].trader]["ETH"]-=(remainder*orders[i].price);
                    orders[i].filled+=remainder;
                    remainder=0;
                }
            }
        }

        for (uint i=orders.length; i>0; i--){
            if (orders[i-1].amount==orders[i-1].filled) {
                for (uint j=i-1; j<orders.length-1; j++){
                    orders[j] = orders[j+1];
                }
                orders.pop();
            }
        }

    }
}