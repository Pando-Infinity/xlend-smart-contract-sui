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
  sleep,
} from "./common.js";
import { createObjectCsvWriter } from "csv-writer";
import { isValidSuiAddress } from "@mysten/sui.js/utils";
import * as path from "path";

const distributedLogWriter = createObjectCsvWriter({
  path: "distributed_nft_output.csv",
  header: [
    { id: "txHash", title: "TxHash" },
    { id: "addresses", title: "Addresses" },
  ],
  append: true,
});

const errorWallets = createObjectCsvWriter({
  path: "wallet_error_output.csv",
  header: [{ id: "walletAddress", title: "walletAddress" }],
  append: true,
});

const invalidWallets = createObjectCsvWriter({
  path: "wallet_invalid_output.csv",
  header: [{ id: "walletAddress", title: "walletAddress" }],
  append: true,
});

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
  const dataToWrite = [
    {
      txHash: res.digest,
      addresses,
    },
  ];
  distributedLogWriter
    .writeRecords(dataToWrite)
    .then(() => console.log("Distribute NFTs result was written successfully"))
    .catch((err) => console.error(err));
};

const distributeNFTs = async () => {
  const addresses = [];
  fs.createReadStream(DISTRIBUTE_NFTS_CSV_PATH)
    .pipe(csvParser())
    .on("error", (err) => {
      console.error("Error while reading CSV file:", err);
    })
    .on("data", (row) => {
      if (isValidSuiAddress(row.walletAddress)) {
        const { walletAddress, quantity } = row;
        for (let i = 0; i < quantity; i++) {
          addresses.push(walletAddress);
        }
      } else {
        console.log("Invalid address:", row.walletAddress);
        invalidWallets
          .writeRecords([{ walletAddress: row.walletAddress }])
          .then(() => console.log("Write invalid address log done"))
          .catch((err) => console.error(err));
      }
    })
    .on("end", async () => {
      console.log("Read distribute nfts csv file successfully");
      const chunkAddresses = splitAddresses(addresses);
      for (const chunk of chunkAddresses) {
        try {
          console.log(chunk);
          await submitDistributeNFts(chunk);
        } catch (err) {
          console.log("Failed to distribute nfts to addresses:", chunk, err);
          const dataToWrite = [
            {
              txHash: `Error ${err.message}`,
              addresses: chunk,
            },
          ];

          distributedLogWriter
            .writeRecords(dataToWrite)
            .then(() => console.log("Write error log done"))
            .catch((err) => console.error(err));

          errorWallets
            .writeRecords(chunk.map((walletAddress) => ({ walletAddress })))
            .then(() => console.log("Write error log done"))
            .catch((err) => console.error(err));
        }
        await sleep(3000); // Sleep 3s
      }
    });
};

distributeNFTs();
