// Used by tools/check_studio_web.sh. Opens the Studio's web build in
// Chromium twice in one browser profile: "?check=make" makes a story, then
// "?check=reopen" checks that the browser kept it and that it plays
// (studio/web/web_check.gd). Saves a screenshot of each visit and exits
// with 1 on any problem.
//
// Usage: node check.js <page url> <screenshot folder>
// CHROMIUM may name the browser to use.

const { chromium } = require("playwright");
const path = require("path");

const [url, shots] = process.argv.slice(2);

async function visit(page, step) {
	const result = new Promise((resolve) => {
		const timer = setTimeout(() => resolve(`STUDIO CHECK ${step} failed: no answer in 120 seconds`), 120000);
		page.on("console", (message) => {
			const text = message.text();
			if (text.startsWith("STUDIO CHECK")) {
				console.log(text);
			}
			if (text.startsWith(`STUDIO CHECK ${step} `)) {
				clearTimeout(timer);
				resolve(text);
			}
			if (/SCRIPT ERROR/.test(text)) {
				console.log(text);
			}
		});
	});
	await page.goto(`${url}?check=${step}`);
	const answer = await result;
	await page.screenshot({ path: path.join(shots, `${step}.png`) });
	page.removeAllListeners("console");
	return answer.endsWith(" passed");
}

(async () => {
	const browser = await chromium.launch({
		executablePath: process.env.CHROMIUM || undefined,
		args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
	});
	const context = await browser.newContext({ viewport: { width: 1366, height: 1024 } });
	const page = await context.newPage();
	page.on("pageerror", (error) => console.log(`Page error: ${error.message}`));
	let passed = await visit(page, "make");
	passed = (await visit(page, "reopen")) && passed;
	await browser.close();
	process.exit(passed ? 0 : 1);
})().catch((error) => {
	console.log(error);
	process.exit(1);
});
