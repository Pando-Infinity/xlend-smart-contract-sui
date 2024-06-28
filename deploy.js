import { exec } from "child_process";
import dotenv from "dotenv";
import { getFullnodeUrl, SuiClient } from "@mysten/sui.js/client";
import fs from "fs";

// Load environment variables from .env file
dotenv.config();
const objectType = [
  {name : "version", type : "::version::Version"},
  {name : "adminCap", type : "::admin::AdminCap"},
  {name : "operatorCap", type : "::operator::OperatorCap"},
  {name : "upgradeCap", type : "::package::UpgradeCap"},
];
// Define the command to be executed
const command =
  "sui client publish --gas-budget 300000000 --skip-dependency-verification";

// Function to execute the command
function executeCommand(command) {
  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error(`Error: ${error.message}`);
      return;
    }

    if (stderr) {
      console.error(`stderr: ${stderr}`);
    }

    const digest = stdout.substring(20, 64);

    export_env(digest);

    return;
  });
}

const export_env = async (digest) => {
  // Replace with your own endpoint if necessary
  const client = new SuiClient({ url: getFullnodeUrl("testnet") });

  const res = await client.getTransactionBlock({
    digest: digest,
    options: {
      showObjectChanges: true,
    },
  });
  let data = "";
  for (let i = 0; i < res.objectChanges.length; i++) {
    if (res.objectChanges[i].objectType !== undefined) {
      const length = res.objectChanges[i].objectType.length;
      const indexOfDot = res.objectChanges[i].objectType.indexOf(":");
      const typeObject = res.objectChanges[i].objectType.substring(indexOfDot, length);
      for (let j = 0; j < objectType.length; j++) {
          if (typeObject == objectType[j].type) {
            data += `${objectType[j].name}=${res.objectChanges[i].objectId}\n`;
          }
      }
    } else {
        data += `PackageID=${res.objectChanges[i].packageId}\n`;
    }
    fs.writeFile("deploy.json", data, (err) => {
      if (err) throw err;
      console.log("Dữ liệu đã được ghi vào file deploy.json");
    });
  }
};

executeCommand(command);
