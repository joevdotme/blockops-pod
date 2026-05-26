"use strict";

const { execFileSync } = require("node:child_process");

function cast(args) {
  return execFileSync("cast", args, {
    encoding: "utf8",
    env: process.env,
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

module.exports = {
  cast,
};
