import { HardhatRuntimeEnvironment, TaskArguments } from "hardhat/types";
import {
  CONTRACT_NAME,
  DEFAULT_ENV,
  DEPLOY_TREASURY_CONTRACT,
  VERIFY_TREASURY_CONTRACT,
  EXCHANGE_TOKEN,
} from "../../constants";
import { task } from "hardhat/config";
import {
  ContractType,
  recordAllDeployments,
  saveDeployments,
  getDeployments,
  IDeploymentAdapters,
} from "../../utils";
import ERC1967Proxy from "@openzeppelin/contracts/build/contracts/ERC1967Proxy.json";

const contractName: string = CONTRACT_NAME.Treasury;
const contractType = ContractType.Intializable;

task(DEPLOY_TREASURY_CONTRACT)
  .addFlag("verify", "pass true to verify the contract")
  .setAction(async function (
    _taskArguments: TaskArguments,
    _hre: HardhatRuntimeEnvironment
  ) {
    let env = process.env.ENV;
    if (!env) env = DEFAULT_ENV;

    const network = await _hre.getChainId();

    console.log(`Deploying ${contractName} Contract on chainId ${network}....`);
    const factory = await _hre.ethers.getContractFactory("Treasury");
    const treasury = await factory.deploy();
    console.log("Treasury deployed to:", treasury.address);
    await treasury.deployed();
    const { abi } = await _hre.artifacts.readArtifact("Treasury");
    const iface = new _hre.ethers.utils.Interface(abi);

    const deployments = getDeployments(contractType) as IDeploymentAdapters;
    let drypToken;
    for (let i = 0; i < deployments[env][network].length; i++) {
      if (deployments[env][network][i].name === "Dryp") {
        drypToken = deployments[env][network][i].address;
        break;
      }
    }
    const drypPool = drypToken;
    const treasuryManager = "0xBec33ce33afdAF5604CCDF2c4b575238C5FBD23d";

    const callInitialize = iface.encodeFunctionData("initialize", [
      drypToken,
      drypPool,
      treasuryManager,
      EXCHANGE_TOKEN["11155111"].usdc.address,
      EXCHANGE_TOKEN["11155111"].usdt.address,
    ]);
    console.log("Treasury Initialize", callInitialize);
    const Proxy = await _hre.ethers.getContractFactory(
      ERC1967Proxy.abi,
      ERC1967Proxy.bytecode
    );
    const proxy = await Proxy.deploy(treasury.address, callInitialize);
    console.log("Proxy deployed to:", proxy.address);

    const deployment = await recordAllDeployments(
      env,
      network,
      contractType,
      contractName,
      treasury.address
    );

    await saveDeployments(contractType, deployment);

    const deploymentProxy = await recordAllDeployments(
      env,
      network,
      ContractType.Proxy,
      CONTRACT_NAME.TreasuryProxy,
      proxy.address
    );

    await saveDeployments(contractType, deploymentProxy);

    console.log(`${contractName} contract deployed at`, treasury.address);
    console.log(`_taskArguments`, _taskArguments);
    if (_taskArguments.verify === true) {
      await _hre.run(VERIFY_TREASURY_CONTRACT);
    }
  });

task(VERIFY_TREASURY_CONTRACT).setAction(async function (
  _taskArguments: TaskArguments,
  _hre: HardhatRuntimeEnvironment
) {
  let env = process.env.ENV;
  if (!env) env = DEFAULT_ENV;

  const network = await _hre.getChainId();

  const deployments = getDeployments(contractType) as IDeploymentAdapters;
  let address;
  for (let i = 0; i < deployments[env][network].length; i++) {
    if (deployments[env][network][i].name === contractName) {
      address = deployments[env][network][i].address;
      break;
    }
  }
  console.log(`Verifying ${contractName} Contract....`);
  await _hre.run("verify:verify", {
    address,
    constructorArguments: ["DRYP", "dryp"],
  });

  console.log(`Verified ${contractName} contract address `, address);
});
