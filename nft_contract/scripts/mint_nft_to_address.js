import { SuiClient } from "@mysten/sui.js/client";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import {
  RPC_URL,
  VERSION,
  OPERATOR_PRIVATE_KEY,
  UPGRADED_PACKAGE,
  OPERATOR_CAP,
} from "./environment.js";
import {
  NFT_ATTRIBUTE_KEYS,
  NFT_ATTRIBUTE_VALUES,
  NFT_DESCRIPTION,
  NFT_IMAGE_URL,
  NFT_NAME,
  NFT_SYMBOL,
  getSignerByPrivateKey,
} from "./common.js";

const RECEIVER =
  "0x617ce17e18de5d44e43af3a3a3e2bec0c45812d4fb9ba0da7bb95b9fd7e150fe";

export const mint_nft_to_address = async () => {
  const suiClient = new SuiClient({ url: RPC_URL });
  const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

  const tx = new TransactionBlock();
  const functionTarget = `${UPGRADED_PACKAGE}::operator::mint_nft_to_address`;
  tx.moveCall({
    target: functionTarget,
    arguments: [
      tx.object(OPERATOR_CAP),
      tx.object(VERSION),
      tx.pure.string(NFT_NAME),
      tx.pure.string(NFT_SYMBOL),
      tx.pure.string(NFT_DESCRIPTION),
      tx.pure.string(NFT_IMAGE_URL),
      tx.pure(NFT_ATTRIBUTE_KEYS),
      tx.pure(NFT_ATTRIBUTE_VALUES),
      tx.pure.address(RECEIVER),
    ],
  });

  const res = await suiClient.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    signer,
  });

  console.log({ response: res }, "Mint Nft to address");
};

mint_nft_to_address();
