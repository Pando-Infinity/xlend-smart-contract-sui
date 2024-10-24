import { SuiClient } from "@mysten/sui.js/client";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { getSignerByPrivateKey } from "./common.js";

const RPC_URL = "https://devnet.baku.movementlabs.xyz:443";

const privateKey =
  "suiprivkey1qqtjnkrm6m42udkuw890z503kelpmm4u7g5wec0k22xl0fx7p9jszfrdu96";
const coinType =
  "0x8ac626e474c33520a815175649fefcbb272678c8c37a7b024e7171fa45d47711::usdc::USDC";

const burnCoin = async () => {
  const suiClient = new SuiClient({ url: RPC_URL });
  const signer = getSignerByPrivateKey(privateKey);

  let cursor = null;
  //Burn Zero Coin
  //   while (true) {
  //     try {
  //       const tx = new TransactionBlock();
  //       const paginatedCoins = await suiClient.getAllCoins({
  //         owner: signer.getPublicKey().toSuiAddress(),
  //         cursor,
  //       });
  //       cursor = paginatedCoins.nextCursor;
  //       const coinsFiltered = paginatedCoins.data.filter(
  //         (coin) => coin.coinType === coinType && Number(coin.balance) == 0
  //       );
  //       if (coinsFiltered.length == 0) {
  //         console.log("Empty Zero Coin");
  //         break;
  //       }
  //       for (const coin of coinsFiltered) {
  //         console.log("destroy coin", coin.coinObjectId);
  //         tx.moveCall({
  //           target: `0x0000000000000000000000000000000000000000000000000000000000000002::coin::burn`,
  //           typeArguments: [coinType],
  //           arguments: [
  //             tx.object(
  //               "0x6bad1a88caef6f9ea56680cd31315b2cfeb6018b105471320407559042e6d067"
  //             ),
  //             tx.object(coin.coinObjectId),
  //           ],
  //         });
  //       }

  //       const res = await suiClient.signAndExecuteTransactionBlock({
  //         transactionBlock: tx,
  //         signer,
  //       });

  //       console.log({ response: res }, "Burn zero coin");

  //       await new Promise((resolve) => setTimeout(resolve, 2000));

  //       if (!paginatedCoins.hasNextPage) break;
  //     } catch (err) {
  //       console.log(err);
  //       continue;
  //     }
  //   }

  //Merge coin
  while (true) {
    try {
      const tx = new TransactionBlock();
      const paginatedCoins = await suiClient.getAllCoins({
        owner: signer.getPublicKey().toSuiAddress(),
      });

      const coinsFiltered = paginatedCoins.data.filter(
        (coin) => coin.coinType === coinType
      );

      const coins = coinsFiltered.map((coin) => coin.coinObjectId);

      if (coins.length > 1) {
        console.log(coins);
        const [destinationCoin, ...restCoin] = coins;
        tx.mergeCoins(destinationCoin, restCoin);

        const res = await suiClient.signAndExecuteTransactionBlock({
          transactionBlock: tx,
          signer,
        });

        await new Promise((resolve) => setTimeout(resolve, 2000));
      }

      cursor = paginatedCoins.nextCursor;

      if (!paginatedCoins.hasNextPage || !cursor) break;
    } catch (err) {
      console.error(err);
      continue;
    }
  }
};

burnCoin();
