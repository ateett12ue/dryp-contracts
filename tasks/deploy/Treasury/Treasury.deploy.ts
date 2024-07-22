import hre from "hardhat";
import ERC1967Proxy from "@openzeppelin/contracts/build/contracts/ERC1967Proxy.json";
import ether from "ethers";
import { EXCHANGE_TOKEN } from "../../constants";

async function main() {
  await hre.run("compile");

  // deploy initial contract
  const Treasury = await hre.ethers.getContractFactory("Treasury");
  const myTreasury = await Treasury.deploy();
  console.log("Treasury 1.0 deployed to:", myTreasury.address);

  // calculate initialize() call during deployment
  const { abi } = await hre.artifacts.readArtifact("Treasury");
  const iface = new ether.utils.Interface(abi);
  const callInitialize = iface.encodeFunctionData("initialize", [
    "__drypToken",
    "__drypPool",
    "0xBec33ce33afdAF5604CCDF2c4b575238C5FBD23d",
    "0xBec33ce33afdAF5604CCDF2c4b575238C5FBD23d",
    EXCHANGE_TOKEN[11155111].usdc.address,
    EXCHANGE_TOKEN[11155111].usdt.address,
  ]);

  // deploy proxy
  const Proxy = await hre.ethers.getContractFactory(
    ERC1967Proxy.abi,
    ERC1967Proxy.bytecode
  );
  const proxy = await Proxy.deploy(myTreasury.address, callInitialize);
  console.log("Proxy deployed to:", proxy.address);

  // fs.writeFileSync(
  //   "./status.json",
  //   JSON.stringify(
  //     { proxyAddress: proxy.address, myTreasury_v1Address: myTreasury.address },
  //     "",
  //     2
  //   )
  // );
}

main()
  .then(() => {
    return 0;
  })
  .catch((error) => {
    console.error("error", error);
    // process.exit(1);
  });
