import { HardhatRuntimeEnvironment, TaskArguments } from "hardhat/types";
import {
  CONTRACT_NAME,
  DEFAULT_ENV,
  DEPLOY_SAMPLE,
  VERIFY_SAMPLE,
  NATIVE,
  WNATIVE,
} from "../constants";
import { task } from "hardhat/config";
import {
  ContractType,
  IDeployment,
  getDeployments,
  recordAllDeployments,
  saveDeployments,
} from "../utils";

const contractName: string = CONTRACT_NAME.Sample;
const contractType = ContractType.None;

task(DEPLOY_SAMPLE)
  .addFlag("verify", "pass true to verify the contract")
  .setAction(async function (
    _taskArguments: TaskArguments,
    _hre: HardhatRuntimeEnvironment
  ) {
    let env = process.env.ENV;
    if (!env) env = DEFAULT_ENV;

    const network = await _hre.getChainId();

    console.log(`Deploying ${contractName} Contract on chainId ${network}....`);
    const factory = await _hre.ethers.getContractFactory(contractName);
    const instance = await factory.deploy(
      NATIVE,
      WNATIVE[env][network]
    );
    await instance.deployed();

    const deployment = await recordAllDeployments(
      env,
      network,
      contractType,
      contractName,
      instance.address
    );

    await saveDeployments(contractType, deployment);

    console.log(`${contractName} contract deployed at`, instance.address);

    if (_taskArguments.verify === true) {
      await _hre.run(VERIFY_SAMPLE);
    }
  });

task(VERIFY_SAMPLE).setAction(async function (
  _taskArguments: TaskArguments,
  _hre: HardhatRuntimeEnvironment
) {
  let env = process.env.ENV;
  if (!env) env = DEFAULT_ENV;

  const network = await _hre.getChainId();

  const deployments = getDeployments(contractType) as IDeployment;
  const address = deployments[env][network][contractName];

  console.log(`Verifying ${contractName} Contract....`);
  await _hre.run("verify:verify", {
    address,
    constructorArguments: [
      NATIVE,
      WNATIVE[env][network]
    ],
  });

  console.log(`Verified ${contractName} contract address `, address);
});
