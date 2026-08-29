#!/usr/bin/env node

import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");

const [htmlPath, pdfPath] = process.argv.slice(2);
if (!htmlPath || !pdfPath) {
  throw new Error("usage: print-html-pdf.mjs INPUT.html OUTPUT.pdf");
}

const executablePath = process.env.HEVEA_CHROME_PATH
  ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const browser = await chromium.launch({ executablePath, headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  await page.goto(pathToFileURL(htmlPath).href, { waitUntil: "networkidle" });
  await page.waitForFunction(
    () => document.documentElement.dataset.mathReady === "true",
    undefined,
    { timeout: 60_000 },
  );
  await page.emulateMedia({ media: "print" });

  const mathContainerCount = await page.locator("mjx-container").count();
  const imageCount = await page.locator("img.exhibit-image").count();
  if (mathContainerCount < 40) {
    throw new Error(`MathJax rendered only ${mathContainerCount} containers`);
  }

  await page.pdf({
    path: pdfPath,
    format: "Letter",
    printBackground: true,
    displayHeaderFooter: true,
    headerTemplate: "<span></span>",
    footerTemplate: `
      <div style="width:100%;font-size:8px;color:#64748b;padding:0 0.55in;display:flex;justify-content:space-between;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
        <span>HEVEA VISION · REDUCED SPHERE / NSA READER</span>
        <span><span class="pageNumber"></span> / <span class="totalPages"></span></span>
      </div>`,
    margin: { top: "0.62in", right: "0.68in", bottom: "0.68in", left: "0.68in" },
  });

  process.stdout.write(`${JSON.stringify({ mathContainerCount, imageCount })}\n`);
} finally {
  await browser.close();
}
