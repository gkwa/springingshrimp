import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3"
import { UsageRecord } from "../src/models/UsageData"

export class S3FileManager {
  private readonly s3Client: S3Client
  private readonly bucket: string

  constructor(bucket: string) {
    this.bucket = bucket
    this.s3Client = new S3Client({})
  }

  private getS3Key(timestamp: string, extension: string): string {
    const date = new Date()
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")

    return `data/${year}/${month}/${day}/astound-data-usage-${timestamp}.${extension}`
  }

  async saveScreenshot(page: any, timestamp: string): Promise<void> {
    const screenshot = await page.screenshot({ fullPage: true })
    const key = this.getS3Key(timestamp, "png")

    await this.s3Client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: screenshot,
        ContentType: "image/png",
      }),
    )

    console.log(`Screenshot saved to s3://${this.bucket}/${key}`)
  }

  async saveText(content: string, timestamp: string): Promise<void> {
    const key = this.getS3Key(timestamp, "txt")

    await this.s3Client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: content,
        ContentType: "text/plain",
      }),
    )

    console.log(`Text file saved to s3://${this.bucket}/${key}`)
  }

  async saveHtml(content: string, timestamp: string): Promise<void> {
    const key = this.getS3Key(timestamp, "html")

    await this.s3Client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: content,
        ContentType: "text/html",
      }),
    )

    console.log(`HTML file saved to s3://${this.bucket}/${key}`)
  }

  async saveUsageRecord(record: UsageRecord, timestamp: string): Promise<void> {
    const key = this.getS3Key(timestamp, "json")

    await this.s3Client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: JSON.stringify(record, null, 2),
        ContentType: "application/json",
      }),
    )

    console.log(`Usage record saved to s3://${this.bucket}/${key}`)
  }
}

