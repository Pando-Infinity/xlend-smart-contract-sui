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
  sleep,
} from "./common.js";

const RECEIVER = "";
const TOTAL_MINT = 1;
const PER_MINT = 1;

export const mint_nft_to_address = async () => {
  const suiClient = new SuiClient({ url: RPC_URL });
  const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

  let totalMinted = 0;
  while (totalMinted < TOTAL_MINT) {
    try {
      const tx = new TransactionBlock();
      const functionTarget = `${UPGRADED_PACKAGE}::operator::mint_nft_to_address`;
      for (let i = 0; i < PER_MINT; i++) {
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
      }
      const res = await suiClient.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer,
      });
      totalMinted += PER_MINT;
      console.log(`Minted ${totalMinted} NFTs`);
    } catch (err) {
      console.log(`Failed to mint NFTs: ${err}`);
    }
    await sleep(2000);
  }
};

mint_nft_to_address();
