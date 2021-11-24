const Dex = artifacts.require("Dex");
const Link = artifacts.require("Link");
const truffleAssert = require("truffle-assertions")

contract("Dex", accounts => {
    it("should throw an error if ETH balance is too low when creating BUY list order", async () => {
        let dex = await Dex.deployed();
        let link = await Link.deployed();
        await truffleAssert.reverts(
            dex.createLimitOrder(0, web3.utils.fromUtf8("LINK"), 1, 10)
        )
        let zero_address = "0x0000000000000000000000000000000000000000";
        await dex.addToken(web3.utils.fromUtf8("ETH"), zero_address, {from:accounts[0]})
        await dex.depositEth({value:10});
        await truffleAssert.passes(
            dex.createLimitOrder(0, web3.utils.fromUtf8("LINK"), 1, 10)
        )
    })
    it("should throw an error if token balance is too low when creating SELL list order", async () => {
        let dex = await Dex.deployed();
        let link = await Link.deployed();
        await truffleAssert.reverts(
            dex.createLimitOrder(1, web3.utils.fromUtf8("LINK"), 1, 10)
        )
        await link.approve(dex.address, 500);
        await dex.addToken(web3.utils.fromUtf8("LINK"), link.address, {from:accounts[0]})
        await dex.deposit(100, web3.utils.fromUtf8("LINK"));
        await truffleAssert.passes(
            dex.createLimitOrder(1, web3.utils.fromUtf8("LINK"), 1, 10)
        )
    })
    it("should ensure that the BUY order list is ordered on price from highest to lowest starting at index 0", async () => {
        let dex = await Dex.deployed();
        let link = await Link.deployed();
        await link.approve(dex.address, 500);
        await dex.depositEth({value:3000});
        await dex.createLimitOrder(0, web3.utils.fromUtf8("LINK"), 1, 300)
        await dex.createLimitOrder(0, web3.utils.fromUtf8("LINK"), 1, 20)
        await dex.createLimitOrder(0, web3.utils.fromUtf8("LINK"), 1, 100)
        await dex.createLimitOrder(0, web3.utils.fromUtf8("LINK"), 1, 200)

        let orderbook = await dex.getOrderBook(web3.utils.fromUtf8("LINK"), 0);
        assert(orderbook.length > 0);
        for (let i=0; i<orderbook.length-1; i++){
            assert(parseInt(orderbook[i].price) >= parseInt(orderbook[i+1].price), "not right order in buy book")
        }
    })
    // [30, 374,432, 43, 53]
    it("should ensure that the SELL order list is ordered on price from lowest to highnest starting at index 0", async () => {
        let dex = await Dex.deployed();
        let link = await Link.deployed();
        await link.approve(dex.address, 500);
        await dex.deposit(500, web3.utils.fromUtf8("LINK"));
        await dex.createLimitOrder(1, web3.utils.fromUtf8("LINK"), 2, 300)
        await dex.createLimitOrder(1, web3.utils.fromUtf8("LINK"), 2, 100)
        await dex.createLimitOrder(1, web3.utils.fromUtf8("LINK"), 2, 200)
        await dex.createLimitOrder(1, web3.utils.fromUtf8("LINK"), 2, 20)

        let orderbook = await dex.getOrderBook(web3.utils.fromUtf8("LINK"), 1);
        assert(orderbook.length > 0);
        for (let i=0; i<orderbook.length-1; i++){
            assert(parseInt(orderbook[i].price) <= parseInt(orderbook[i+1].price), "not right order in buy book");
        }
    })
    it("should ensure that BUY limit orders are filled when they have matching orders from the SELL order book", async () => {
        let dex = await Dex.deployed()
        let link = await Link.deployed();

        let orderbook = await dex.getOrderBook(web3.utils.fromUtf8("LINK"), 1); //Get sell side orderbook
        let n=orderbook.length;
        assert(orderbook.length == n, "Sell side Orderbook length should be equal to n at start of this test due to sell orders from previous tests");

        let buyOrderbook = await dex.getOrderBook(web3.utils.fromUtf8("LINK"), 0); //Get buy side orderbook
        let m=buyOrderbook.length;
        assert(buyOrderbook.length == m, "Buy side Orderbook length should be equal to n at start of this test due to buy orders from previous tests");
        
        await dex.createLimitOrder(0, web3.utils.fromUtf8("LINK"), 2, 300); //

        orderbook = await dex.getOrderBook(web3.utils.fromUtf8("LINK"), 1); //Get sell side orderbook
        assert.equal(orderbook.length, n-1)

        buyOrderbook = await dex.getOrderBook(web3.utils.fromUtf8("LINK"), 0); //Get buy side orderbook
        assert.equal(buyOrderbook.length, m+1); // Ascertain that the remainder of the last buy order was added to orderbook

        let newest=0;

        // Get the last buy order with price 300wei
        for (let i=0; i<buyOrderbook.length; i++){
            if (buyOrderbook[i].price=="300" && parseInt(buyOrderbook[i].id) > parseInt(buyOrderbook[newest].id)){
                newest=i;
            }
        }
        assert.equal(buyOrderbook[newest].filled, 1); // filled 1 of 2
        assert.equal(buyOrderbook[newest].amount, 2);
    })
    it("should ensure that SELL limit orders are filled when they have matching orders from the BUY order book", async () => {
        let dex = await Dex.deployed()
        let link = await Link.deployed();

        let orderbook = await dex.getOrderBook(web3.utils.fromUtf8("LINK"), 0); //Get buy side orderbook
        let n=orderbook.length;
        assert(orderbook.length == n, "Buy side Orderbook length should be equal to n at start of this test due to sell orders from previous tests");

        let sellOrderbook = await dex.getOrderBook(web3.utils.fromUtf8("LINK"), 1); //Get sell side orderbook
        let m=sellOrderbook.length;
        assert(sellOrderbook.length == m, "Sell side Orderbook length should be equal to n at start of this test due to buy orders from previous tests");
        
        await dex.createLimitOrder(1, web3.utils.fromUtf8("LINK"), 2, 300); //

        orderbook = await dex.getOrderBook(web3.utils.fromUtf8("LINK"), 0); //Get buy side orderbook
        assert.equal(orderbook.length, n-1)

        sellOrderbook = await dex.getOrderBook(web3.utils.fromUtf8("LINK"), 1); //Get sell side orderbook
        assert.equal(sellOrderbook.length, m+1); // Ascertain that the remainder of the last sell order was added to orderbook

        let newest=0;

        // Get the last buy order with price 300wei
        for (let i=0; i<sellOrderbook.length; i++){
            if (sellOrderbook[i].price=="300" && parseInt(sellOrderbook[i].id) > parseInt(sellOrderbook[newest].id)){
                newest=i;
            }
        }
        assert.equal(sellOrderbook[newest].filled, 1); // filled 1 of 2
        assert.equal(sellOrderbook[newest].amount, 2);
    })
})