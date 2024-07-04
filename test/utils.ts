/* eslint-disable node/no-unsupported-features/es-syntax */
import axios from "axios";
import { defaultAbiCoder } from "ethers/lib/utils";
import { NATIVE } from "../tasks/constants";
import { ContractReceipt, ethers, Wallet } from "ethers";


export const decodeUnsupportedOperationEvent = (
  txReceipt: ContractReceipt
): { token: string; refundAddress: string; refundAmount: string } => {
  const EventInterface = new ethers.utils.Interface([
    "event UnsupportedOperation(address token,address refundAddress,uint256 amount)",
  ]);

  const unsupportedOperationEvent = txReceipt.logs.filter(
    (_log: any) =>
      _log.topics[0] === EventInterface.getEventTopic("UnsupportedOperation")
  );

  const eventData = EventInterface.decodeEventLog(
    "UnsupportedOperation",
    unsupportedOperationEvent[0].data,
    unsupportedOperationEvent[0].topics
  );

  const [token, refundAddress, refundAmount] = [
    eventData[0],
    eventData[1],
    eventData[2],
  ];

  return { token, refundAddress, refundAmount };
};

export const decodeExecutionEvent = (
  txReceipt: ContractReceipt
): { name: string; data: string } => {
  const EventInterface = new ethers.utils.Interface([
    "event ExecutionEvent(string indexed adapterName, bytes data)",
  ]);

  const executionEvent = txReceipt.logs.filter(
    (_log: any) =>
      _log.topics[0] === EventInterface.getEventTopic("ExecutionEvent")
  );

  const eventData = EventInterface.decodeEventLog(
    "ExecutionEvent",
    executionEvent[0].data,
    executionEvent[0].topics
  );

  // name is the hash of the string passed on the contract
  // example: for UniswapV3Mint adapter, name is keccak256("UniswapV3Mint")
  return { name: eventData[0], data: eventData[1] };
};
