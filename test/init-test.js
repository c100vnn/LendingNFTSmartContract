const {assert} = require('chai');
// const {artifacts} = require('@nomiclabs/hardhat-truffle5');

const Loc = artifacts.require('Loc');
const WrapERC721DualRole = artifacts.require('WrapERC721DualRole');
const DoNFTFactory = artifacts.require('DoNFTFactory');


contract('DemoERC4907', () => {

    const publicProp = [2000, 200, 5, web3.utils.toWei('0.0001')];
   const privateProp = [2000, 200, 5, web3.utils.toWei('0.001')];
   const dutchAuctionProp = [2000, 200, 5, web3.utils.toWei('0.001'), web3.utils.toWei('0.0001'), 10000, 1000];
   // const dutchAuctionProp = [2000, 200, 5, 1000000000000000, 100000000000000, 10000, 1000];
   const publicMintStartingTimestamp = 1653648524;
   const privateMintStartingTimestamp = 1653648529;

   let accounts;
   let accountAdmin;
   let accountDev;
   let locNFT;
   let wrapLocDualRole;
   let doNFTFactory;

   before(async () => {
      accounts = await web3.eth.getAccounts();
      accountAdmin = accounts[0];
      accountDev = accounts[1];
   });

   before(async () => {
      locNFT = await Loc.new(
         publicProp,
         privateProp,
         dutchAuctionProp,
         publicMintStartingTimestamp,
         privateMintStartingTimestamp,
         accountAdmin
         , {from: accountDev});
      wrapLocDualRole = await WrapERC721DualRole("Loc", "loc", locNFT.address);
      doNFTFactory = await DoNFTFactory("")
   });

//    it('should set user to Bob', async () => {
//       // Get initial balances of first and second account.
//       const Alice = accounts[1];
//       const Bob = accounts[2];
//       //
//       // const instance = await ERC4907Demo.deployed('T', 'T');
//       // const demo = instance;
//
//       await demo.mint(1, Alice);
//       let expires = Math.floor(new Date().getTime() / 1000) + 1000;
//       await demo.setUser(1, Bob, BigInt(expires), {from: Alice});
//
//       let user_1 = await demo.userOf(1);
//
//       assert.equal(
//          user_1,
//          Bob,
//          'User of NFT 1 should be Bob'
//       );
//
//       let owner_1 = await demo.ownerOf(1);
//       assert.equal(
//          owner_1,
//          Alice,
//          'Owner of NFT 1 should be Alice'
//       );
//    });
});
