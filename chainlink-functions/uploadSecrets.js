const { SecretsManager, createGist } = require("@chainlink/functions-toolkit");
const { ethers } = require("ethers");
require("@chainlink/env-enc").config();

const routerAddress = "0xf9B8fc078197181C841c296C876945aaa425B278";
const donId = "fun-base-sepolia-1";


const rpcUrl = process.env.BASE_SEPOLIA_RPC_URL; 

const ethersProvider = new ethers.providers.JsonRpcProvider(
  rpcUrl
);

console.log("CoinMarketCap API Key: ", process.env.COINMARKETCAP_API_KEY);

console.log("RPC URL: ", rpcUrl);


const secrets = { API_KEY: process.env.COINMARKETCAP_API_KEY, RPC_URL: rpcUrl };


const privateKey = process.env.PRIVATE_KEY; 
if (!privateKey)
  throw new Error(
    "Private key not provided - check your environment variables"
  );

if (!rpcUrl)
  throw new Error("RPC URL not provided - check your environment variables");

const wallet = new ethers.Wallet(privateKey);
const signer = wallet.connect(ethersProvider); 


const uploadSecrets = async () => {
  
  const secretsManager = new SecretsManager({
    signer: signer,
    functionsRouterAddress: routerAddress,
    donId: donId,
  });
  await secretsManager.initialize();

  
  const encryptedSecretsObj = await secretsManager.encryptSecrets(secrets);

  console.log(`Creating gist...`);
  const githubApiToken = process.env.GITHUB_API_TOKEN;
  if (!githubApiToken)
    throw new Error(
      "githubApiToken not provided - check your environment variables"
    );

  // Create a new GitHub Gist to store the encrypted secrets
  const gistURL = await createGist(
    githubApiToken,
    JSON.stringify(encryptedSecretsObj)
  );
  console.log(`\n✅Gist created ${gistURL} . Encrypt the URLs..`);
  const encryptedSecretsUrls = await secretsManager.encryptSecretsUrls([
    gistURL,
  ]);

  console.log(`✅Script Completed! Secrets Encrypted with URLS: ${encryptedSecretsUrls}`);
};


uploadSecrets().catch((error) => {
  console.error("Error uploading secrets to DON:", error);
});
