import { decodeSuiPrivateKey } from "@mysten/sui.js/cryptography";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";

export const getSignerByPrivateKey = (privateKey) => {
  const { schema, secretKey } = decodeSuiPrivateKey(privateKey);
  return Ed25519Keypair.fromSecretKey(secretKey, {
    skipValidation: true,
  });
};

export const sleep = (delay) => {
  return new Promise((resolve) => setTimeout(resolve, delay));
};
