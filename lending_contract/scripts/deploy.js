import { exec } from "child_process";
import dotenv from "dotenv";
import { getFullnodeUrl, SuiClient } from "@mysten/sui.js/client";
import fs from "fs";
import { PUBLISH_SMART_CONTRACT_COMMAND } from "./environment.js";
import object_type from './object_type.json' assert { type: 'json' };
// Load environment variables from .env file
dotenv.config();

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
  // // Replace with your own endpoint if necessary
  const client = new SuiClient({ url: getFullnodeUrl("testnet") });

  const res = await client.getTransactionBlock({
    digest: digest,
    options: {
      showObjectChanges: true,
    },
  });

  let data = "";
  for (let i = 0; i < res.objectChanges.length; i++) {
    const object_type_length = object_type.object_type.length;
    if (res.objectChanges[i].objectType !== undefined) {
      const length = res.objectChanges[i].objectType.length;
      const indexOfDot = res.objectChanges[i].objectType.indexOf(":");
      const typeObject = res.objectChanges[i].objectType.substring(
        indexOfDot,
        length
      );
      for (let j = 0; j < object_type_length; j++) {
        if (typeObject == `::${object_type.object_type[j].module}::${object_type.object_type[j].name}`) {
          data += `${object_type.object_type[j].key}=${res.objectChanges[i].objectId}\n`;
        }
      }
    } else {
      data += `${object_type.object_type[object_type_length-1].key}=${res.objectChanges[i].packageId}\n`;
    }
    fs.writeFile("deploy.json", data, (err) => {
      if (err) throw err;
      console.log("Dữ liệu đã được ghi vào file deploy.json");
    });
  }
};

executeCommand(PUBLISH_SMART_CONTRACT_COMMAND);
