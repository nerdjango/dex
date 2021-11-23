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
        await dex.createLimitOrder(1, web3.utils.fromUtf8("LINK"), 1, 300)
        await dex.createLimitOrder(1, web3.utils.fromUtf8("LINK"), 1, 100)
        await dex.createLimitOrder(1, web3.utils.fromUtf8("LINK"), 1, 200)
        await dex.createLimitOrder(1, web3.utils.fromUtf8("LINK"), 1, 20)

        let orderbook = await dex.getOrderBook(web3.utils.fromUtf8("LINK"), 1);
        assert(orderbook.length > 0);
        for (let i=0; i<orderbook.length-1; i++){
            assert(parseInt(orderbook[i].price) <= parseInt(orderbook[i+1].price), "not right order in buy book");
        }
    })
})