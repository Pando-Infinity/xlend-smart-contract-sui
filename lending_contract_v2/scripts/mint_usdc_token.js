import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { getSignerByPrivateKey } from './common';
import { MINT_USDC_PRIVATE_KEY, USDC_TOKEN_PACKAGE, USDC_TOKEN_TREASURY_CAP } from './environment';

const amount = 0;
const receivers = ['', ''];

const mintUsdcToken = async () => {
	const suiClient = new SuiClient({ url: RPC_URL });
  const signer = getSignerByPrivateKey(MINT_USDC_PRIVATE_KEY);

	const tx = new TransactionBlock();
	const funcTarget = `${USDC_TOKEN_PACKAGE}::usdc::mint`
	for (const receiver of receivers) {
		tx.moveCall({
			target: funcTarget,
			arguments: [
				tx.object(USDC_TOKEN_TREASURY_CAP),
				tx.pure.u64(amount),
				tx.pure.address(receiver),
			]
		})
	}

	const res = await suiClient.signAndExecuteTransactionBlock({
		transactionBlock: tx,
		signer,
	});

	console.log({ response: res }, 'Mint usdc token');
}

mintUsdcToken();