import { SuiClient } from "@mysten/sui.js/client";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { getSignerByPrivateKey, sleep } from "./common.js";
import {
  DISTRIBUTE_USDC_TOKEN_CSV_PATH,
  MINT_USDC_PRIVATE_KEY,
  USDC_TOKEN_PACKAGE,
  USDC_TOKEN_TREASURY_CAP,
  PER_CHUNK,
  RPC_URL,
} from "./environment.js";
import fs from "fs";
import csvParser from "csv-parser";
import { createObjectCsvWriter } from "csv-writer";
import { isValidSuiAddress } from "@mysten/sui.js/utils";

const distributedLogWriter = createObjectCsvWriter({
  path: "distributed_usdc_token_output.csv",
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

const mintUsdcToken = async (receivers) => {
  const suiClient = new SuiClient({ url: RPC_URL });
  const signer = getSignerByPrivateKey(MINT_USDC_PRIVATE_KEY);

  //TODO: update this
  const mintAmount = 500000000;

  const tx = new TransactionBlock();
  const funcTarget = `${USDC_TOKEN_PACKAGE}::usdc::mint`;
  for (const receiver of receivers) {
    tx.moveCall({
      target: funcTarget,
      arguments: [
        tx.object(USDC_TOKEN_TREASURY_CAP),
        tx.pure.u64(mintAmount),
        tx.pure.address(receiver),
      ],
    });
  }

  const res = await suiClient.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    signer,
  });

  console.log({ response: res }, "Mint usdc token");
};

const distributeUsdcToken = async () => {
  const receivers = [];
  fs.createReadStream(DISTRIBUTE_USDC_TOKEN_CSV_PATH)
    .pipe(csvParser())
    .on("error", (err) => {
      console.error("Error while reading CSV file:", err);
    })
    .on("data", (row) => {
      receivers.push(row.walletAddress);
      if (isValidSuiAddress(row.walletAddress)) {
        receivers.push(row.walletAddress);
      } else {
        console.log("Invalid address:", row.walletAddress);
        invalidWallets
          .writeRecords([{ walletAddress: row.walletAddress }])
          .then(() => console.log("Write invalid address log done"))
          .catch((err) => console.error(err));
      }
    })
    .on("end", async () => {
      console.log("Read distribute usdc token csv file successfully");
      const chunkAddresses = splitAddresses(receivers);
      for (const chunk of chunkAddresses) {
        try {
          console.log(chunk);
          await mintUsdcToken(chunk);
          await sleep(3000); // Sleep 3s
        } catch (err) {
          console.log(
            "Failed to distribute usdc token to addresses:",
            chunk,
            err
          );
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
      }
    });
};

distributeUsdcToken();
