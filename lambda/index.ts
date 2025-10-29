import { chromium } from "@playwright/test"
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager"
import { AstoundTestRunner } from "../src/services/AstoundTestRunner"
import { S3FileManager } from "./S3FileManager"
import { DataScraper } from "../src/services/DataScraper"
import { UsageRecord } from "../src/models/UsageData"

interface LambdaEvent {
  dryRun?: boolean
}

interface LambdaResponse {
  statusCode: number
  body: string
}

async function getCredentials() {
  const secretArn = process.env.SECRET_ARN
  if (!secretArn) {
    throw new Error("SECRET_ARN environment variable not set")
  }

  const client = new SecretsManagerClient({})
  const command = new GetSecretValueCommand({ SecretId: secretArn })
  const response = await client.send(command)

  if (!response.SecretString) {
    throw new Error("Secret string is empty")
  }

  const secret = JSON.parse(response.SecretString)
  return {
    username: secret.username,
    password: secret.password,
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
    // Get credentials from Secrets Manager
    console.log("Fetching credentials from Secrets Manager...")
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

