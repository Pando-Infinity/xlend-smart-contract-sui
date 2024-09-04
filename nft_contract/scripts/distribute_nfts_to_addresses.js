import { SuiClient } from "@mysten/sui.js/client";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import {
  RPC_URL,
  VERSION,
  OPERATOR_PRIVATE_KEY,
  UPGRADED_PACKAGE,
  OPERATOR_CAP,
  DISTRIBUTE_NFTS_CSV_PATH,
  PER_CHUNK,
} from "./environment.js";
import fs from "fs";
import csvParser from "csv-parser";
import {
  NFT_ATTRIBUTE_KEYS,
  NFT_ATTRIBUTE_VALUES,
  NFT_DESCRIPTION,
  NFT_IMAGE_URL,
  NFT_NAME,
  NFT_SYMBOL,
  getSignerByPrivateKey,
} from "./common.js";

const splitAddresses = (addresses) => {
  const chunkAddresses = addresses.reduce((chunk, item, index) => {
    const chunkIndex = Math.floor(index / PER_CHUNK);

    if (!chunk[chunkIndex]) {
      chunk[chunkIndex] = [];
    }

    chunk[chunkIndex].push(item);

    return chunk;
  }, []);
  return chunkAddresses;
};

const submitDistributeNFts = async (addresses) => {
  const suiClient = new SuiClient({ url: RPC_URL });
  const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);
  const functionTarget = `${UPGRADED_PACKAGE}::operator::mint_nft_to_address`;
  const tx = new TransactionBlock();
  for (const address of addresses) {
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
        tx.pure.address(address),
      ],
    });
  }

  const res = await suiClient.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    signer,
  });
  console.log({ response: res }, "Operator distribute NFTs to addressess");
};

const distributeNFTs = async () => {
  const addresses = [];
  fs.createReadStream(DISTRIBUTE_NFTS_CSV_PATH)
    .pipe(csvParser())
    .on("error", (err) => {
      console.error("Error while reading CSV file:", err);
    })
    .on("data", (row) => {
      addresses.push(row.walletAddress);
    })
    .on("end", async () => {
      console.log("Read distribute nfts csv file successfully");
      const chunkAddresses = splitAddresses(addresses);
      for (const chunk of chunkAddresses) {
        console.log(chunk);
        await submitDistributeNFts(chunk);
      }
    });
};

distributeNFTs();
