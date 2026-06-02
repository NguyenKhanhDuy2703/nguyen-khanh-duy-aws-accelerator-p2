const express = require("express");
const app = express();
app.get("/", (req, res) => res.send("Xin chao tu container"));
app.listen(3000, () => console.log("Server chay tren cong 3000"));
