import { SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { KioskClient, Network } from '@mysten/kiosk';
import { decodeSuiPrivateKey } from "@mysten/sui/cryptography";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

export const getSignerByPrivateKey = (privateKey) => {
  const { schema, secretKey } = decodeSuiPrivateKey(privateKey);
  return Ed25519Keypair.fromSecretKey(secretKey, {
    skipValidation: true,
  });
};

export const placeToPersonalKiosk = async () => {
  const privateKey = 'suiprivkey1qprmy75vs8xapadnfkdr9s6hkeykhgsh864yrmdfwpyrt8g8xr2ljrqdwag';
  const walletAddress = '0x504e35e0f9b48e9c7ba14aa43b2213cbbc12c686c05d41ca3c96d364718e96da'
  const suiClient = new SuiClient({ url: 'https://fullnode.mainnet.sui.io:443' });
  const signer = getSignerByPrivateKey(privateKey);
  const kioskClient = new KioskClient({
    client: suiClient,
    network: Network.MAINNET,
  });
  const kiosks = await kioskClient.getOwnedKiosks({
    address: walletAddress,
  });
  console.log(kiosks);
  const tx = new Transaction();
  const cap = tx.moveCall({
    target: `0x0cb4bcc0560340eb1a1b929cabe56b33fc6449820ec8c1980d69bb98b649b802::personal_kiosk::new`,
    arguments: [
      tx.object('0xbdd698fe9d8591c7e8f91d78c17e28d9bacabf79185c05e27dbc1f6bc90501af'),
      tx.object('0x5983e48e5a07ff108801292e2f067b952500c388e079f03379d3e0ea34a0dd7a'),
    ]
  });
  tx.moveCall({
    target: `0x0cb4bcc0560340eb1a1b929cabe56b33fc6449820ec8c1980d69bb98b649b802::personal_kiosk::transfer_to_sender`,
    arguments: [
      cap,
    ]
  });
  const res = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer,
  });
  console.log(res);
}

placeToPersonalKiosk();