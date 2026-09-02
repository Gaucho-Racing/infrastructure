# Depot's dev bucket + scoped IAM user. Depot does Put/Get/Head/Delete and
# presigned URLs only — no ListBucket. The access key secret is in TF state;
# read it with `terraform output -raw depot_dev_secret_access_key` → each
# developer's .env.
resource "aws_s3_bucket" "depot_dev" {
  region        = "us-west-2"
  bucket        = "gr-depot-dev"
  force_destroy = true
}

resource "aws_s3_bucket" "depot_dev_use1" {
  region = "us-east-1"
  bucket = "gr-depot-dev-use1"
}

resource "aws_s3_bucket_public_access_block" "depot_dev_use1" {
  region = "us-east-1"
  bucket = aws_s3_bucket.depot_dev_use1.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The web UI's presigned upload flow PUTs directly from the browser to S3,
# which is cross-origin from the local kerbecs gateway.
resource "aws_s3_bucket_cors_configuration" "depot_dev_use1" {
  region = "us-east-1"
  bucket = aws_s3_bucket.depot_dev_use1.id

  cors_rule {
    allowed_origins = ["http://localhost:10310"]
    allowed_methods = ["GET", "PUT", "HEAD"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_iam_user" "depot_dev" {
  name = "depot-dev"
}

resource "aws_iam_access_key" "depot_dev" {
  user = aws_iam_user.depot_dev.name
}

resource "aws_iam_user_policy" "depot_dev_s3" {
  name = "depot-dev-s3"
  user = aws_iam_user.depot_dev.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ]
        Resource = "${aws_s3_bucket.depot_dev_use1.arn}/*"
      }
    ]
  })
}
