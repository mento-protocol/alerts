import { JSONSchemaType, envSchema } from "env-schema";

export interface Env {
  DISCORD_WEBHOOK_ALERTS: string;
  DISCORD_WEBHOOK_EVENTS: string;
  MULTISIG_CONFIG: string;
  QUICKNODE_SIGNING_SECRET: string;
  X_AUTH_TOKEN_SECRET_ID: string;
}

const schema: JSONSchemaType<Env> = {
  type: "object",
  required: [
    "DISCORD_WEBHOOK_ALERTS",
    "DISCORD_WEBHOOK_EVENTS",
    "MULTISIG_CONFIG",
    "QUICKNODE_SIGNING_SECRET",
  ],
  properties: {
    DISCORD_WEBHOOK_ALERTS: { type: "string" },
    DISCORD_WEBHOOK_EVENTS: { type: "string" },
    MULTISIG_CONFIG: { type: "string" },
    QUICKNODE_SIGNING_SECRET: { type: "string" },
    X_AUTH_TOKEN_SECRET_ID: { type: "string" },
  },
};

export const config = envSchema({
  schema,
  dotenv: true, // load .env if it is there
});

export default config;
