import { chromium } from "@playwright/test"
import { SSMClient, GetParameterCommand } from "@aws-sdk/client-ssm"
import { DataScraper } from "../src/services/DataScraper"
import { UsageRecord } from "../src/models/UsageData"
import { S3FileManager } from "./S3FileManager"

interface LambdaEvent {
  dryRun?: boolean
}

interface LambdaResponse {
  statusCode: number
  body: string
}

async function getCredentials() {
  const usernameParam = process.env.USERNAME_PARAM
  const passwordParam = process.env.PASSWORD_PARAM

  if (!usernameParam || !passwordParam) {
    throw new Error("USERNAME_PARAM and PASSWORD_PARAM environment variables must be set")
  }

  const client = new SSMClient({})

  const [usernameResult, passwordResult] = await Promise.all([
    client.send(
      new GetParameterCommand({
        Name: usernameParam,
        WithDecryption: true,
      }),
    ),
    client.send(
      new GetParameterCommand({
        Name: passwordParam,
        WithDecryption: true,
      }),
    ),
  ])

  return {
    username: usernameResult.Parameter!.Value!,
    password: passwordResult.Parameter!.Value!,
  }
}

export const handler = async (event: LambdaEvent): Promise<LambdaResponse> => {
  console.log("Lambda function started")
  console.log("Event:", JSON.stringify(event, null, 2))

  const s3Bucket = process.env.S3_BUCKET
  if (!s3Bucket) {
    throw new Error("S3_BUCKET environment variable not set")
  }

  let browser
  let scrapedData
  let record: UsageRecord

  try {
    // Get credentials from SSM Parameter Store
    console.log("Fetching credentials from SSM Parameter Store...")
    const credentials = await getCredentials()

    // Launch browser
    console.log("Launching browser...")
    browser = await chromium.launch({
      headless: true,
      args: [
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "--single-process",
      ],
    })

    const context = await browser.newContext()
    const page = await context.newPage()

    // Initialize S3 file manager
    const fileManager = new S3FileManager(s3Bucket)

    // Initialize scraper
    const scraper = new DataScraper(page)

    // Login and scrape
    console.log("Logging in to Astound...")
    await scraper.login(credentials.username, credentials.password)

    console.log("Scraping data...")
    scrapedData = await scraper.scrape()

    const timestamp = new Date().toISOString().replace(/[:.]/g, "-")

    // Save files to S3
    console.log("Saving files to S3...")
    await fileManager.saveScreenshot(page, timestamp)
    await fileManager.saveText(scrapedData.text, timestamp)
    await fileManager.saveHtml(scrapedData.html, timestamp)

    // Create usage record
    record = {
      date: scrapedData.date,
      amount: scrapedData.usage.current,
      amountUnits: scrapedData.units,
      total: scrapedData.usage.total,
      totalUnits: scrapedData.units,
      overage: scrapedData.usage.overage,
      overageUnits: scrapedData.units,
      scrapedAt: new Date().toISOString(),
    }

    await fileManager.saveUsageRecord(record, timestamp)

    console.log("Scraping completed successfully")
    console.log("Usage data:", JSON.stringify(record, null, 2))

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Scraping completed successfully",
        data: record,
        s3Bucket,
        timestamp,
      }),
    }
  } catch (error) {
    console.error("Error during scraping:", error)

    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Scraping failed",
        error: error instanceof Error ? error.message : String(error),
      }),
    }
  } finally {
    if (browser) {
      console.log("Closing browser...")
      await browser.close()
    }
  }
}
