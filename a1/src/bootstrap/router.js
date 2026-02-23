"use strict";

const { Router } = require("express");
const { storeRoutes } = require("../modules/store");
// [AUTO-ROUTES]



const router = Router();

router.use("/v1/store", storeRoutes);

// [AUTO-USE]

// ── 404 – unmatched API route ──────────────────────────────────────────────
router.use((_req, res) => {
  res
    .status(404)
    .json({ success: false, error: { message: "API endpoint not found" } });
});


module.exports = router;
