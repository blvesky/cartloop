# CartLoop

CartLoop is a static demo store for everyday goods. Shop six illustrated products, edit your cart, apply LOOP10, and place a simulated order. The page keeps checkout details in memory and clears them after a successful order.

## Run the store

From the project directory, start the store with Python 3.

```sh
python3 -m http.server 8080 --bind 127.0.0.1
```

Open [http://localhost:8080](http://localhost:8080). Use fictional checkout details and the test card from the checkout objective.

## Run both Kane checks

Install Chrome, install the CLI with `npm install -g @testmuai/kane-cli`, and authenticate with `kane-cli login`. Stop any server already using port 8080. From the project directory, run the verification command.

```sh
bash verify.sh
```

The script starts the store, passes each plain-English objective to Kane CLI in agent mode, and runs both flows in headless Chrome. It prints each final `run_end` JSON line, preserves the two NDJSON streams and stderr logs under `.testmuai/cartloop/`, and stops the server. It returns success only if both CLI invocations exit zero and both final events report `passed`. [Kane CLI quickstart](https://www.testmuai.com/docs/kane-cli-quickstart) · [Agent mode reference](https://www.testmuai.com/docs/kane-cli-agent-mode)

| Browser flow | What Kane checks |
| --- | --- |
| Discounted checkout | Field Notebook ($18.00) plus Dune Mug ($24.00) gives $42.00. LOOP10 takes off $4.20. Checkout confirms a generated `CL-` order number and $37.80, then empties the cart. |
| Rejected discount | BOGUS on a single Field Notebook shows an inline error and leaves subtotal and total at $18.00. |

## Agent verification loop

1. The coding agent edits `index.html` and runs `bash verify.sh` after each change.
2. Kane drives the browser and returns the run status. On failure, the agent reads stderr for setup problems or the NDJSON step records and evidence for a browser failure. A completed run can report a `session_dir` containing an `evidence/` folder.
3. The agent fixes the cause and reruns both flows. The loop completes when the script exits zero and both `run_end` statuses are `passed`.

## Judging

- **Ships** — A single page supports browsing, cart changes, checkout validation, and order confirmation.
- **Verified** — The checks assert what a shopper can see, including the amount on the final confirmation and the unchanged total after a rejected code.
- **Closed loop** — The same command gives the coding agent structured feedback and a process exit code after every edit.
- **Craft** — The store uses original inline illustrations, a responsive layout, labeled fields, keyboard controls, and cent-based price calculations.

## Verification on this build

Both flows passed in Chromium via Playwright. That browser run also covered quantity changes, item removal, invalid checkout fields, the cleared form, and the mobile layout. Kane CLI 0.10.9 stopped both invocations at authentication before opening Chrome. There are no Kane pass events for this build yet.
