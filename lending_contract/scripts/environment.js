import * as process from "node:process";
import * as dotenv from "dotenv";
dotenv.config();

export const RPC_URL = process.env.RPC_URL || "_";

export const PACKAGE = process.env.PACKAGE || "_";
export const UPGRADE_PACKAGE = process.env.UPGRADED_PACKAGE || "_";
export const VERSION = String(process.env.VERSION) || "_";
export const OPERATOR_CAP = process.env.OPERATOR_CAP || "_";
export const CUSTODIAN = process.env.CUSTODIAN || "_";
export const STATE = process.env.STATE || "_";
export const CONFIGURATION = process.env.CONFIGURATION || "_";

export const OPERATOR_PRIVATE_KEY = process.env.OPERATOR_PRIVATE_KEY || "_";
