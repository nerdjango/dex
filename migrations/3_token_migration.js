const Link = artifacts.require("Link");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(Link);
};
